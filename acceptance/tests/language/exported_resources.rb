test_name "C94788: exported resources using a yaml terminus for storeconfigs" do
require 'oregano/acceptance/environment_utils'
extend Oregano::Acceptance::EnvironmentUtils

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',     # This could be a component of a larger workflow scenario.
    'server'

  # user resource doesn't have a provider on arista
  skip_test if agents.any? {|agent| agent['platform'] =~ /^eos/ } # see PUP-5404, ARISTA-42
  skip_test 'requires oreganoserver to service restart' if @options[:type] != 'aio'

  app_type = File.basename(__FILE__, '.*')
  tmp_environment   = mk_tmp_environment_with_teardown(master, app_type)
  exported_username = 'er0ck'

  teardown do
    step 'stop oregano server' do
      on(master, "service #{master['oreganoservice']} stop")
    end
    step 'remove cached agent pson catalogs from the master' do
      on(master, "rm -f #{File.join(master.oregano['yamldir'],'catalog','*')}",
         :accept_all_exit_codes => true)
    end
    on(master, "mv #{File.join('','tmp','oregano.conf')} #{master.oregano['confdir']}",
       :accept_all_exit_codes => true)
    step 'clean out collected resources' do
      on(hosts, oregano_resource("user #{exported_username} ensure=absent"), :accept_all_exit_codes => true)
    end
  end

  storeconfigs_backend_name = 'pson_storeconfigs'
  step 'create a yaml storeconfigs terminus in the modulepath' do
    moduledir = File.join(environmentpath,tmp_environment,'modules')
    terminus_class_name = 'PsonStoreconfigs'
    manifest = <<MANIFEST
File {
  ensure => directory,
}
file {
  '#{moduledir}':;
  '#{moduledir}/yaml_terminus':;
  '#{moduledir}/yaml_terminus/lib':;
  '#{moduledir}/yaml_terminus/lib/oregano':;
  '#{moduledir}/yaml_terminus/lib/oregano/indirector':;
  '#{moduledir}/yaml_terminus/lib/oregano/indirector/catalog':;
  '#{moduledir}/yaml_terminus/lib/oregano/indirector/facts':;
  '#{moduledir}/yaml_terminus/lib/oregano/indirector/node':;
  '#{moduledir}/yaml_terminus/lib/oregano/indirector/resource':;
}
file { '#{moduledir}/yaml_terminus/lib/oregano/indirector/catalog/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "oregano/indirector/catalog/yaml"
    class Oregano::Resource::Catalog::#{terminus_class_name} < Oregano::Resource::Catalog::Yaml
      def save(request)
        raise ArgumentError.new("You can only save objects that respond to :name") unless request.instance.respond_to?(:name)
        file = path(request.key)
        basedir = File.dirname(file)
        # This is quite likely a bad idea, since we are not managing ownership or modes.
        Dir.mkdir(basedir) unless Oregano::FileSystem.exist?(basedir)
        begin
          # We cannot dump anonymous modules in yaml, so dump to json/pson
          File.open(file, "w") { |f| f.write request.instance.to_pson }
        rescue TypeError => detail
          Oregano.err "Could not save \#{self.name} \#{request.key}: \#{detail}"
        end
      end
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/oregano/indirector/facts/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "oregano/indirector/facts/yaml"
    class Oregano::Node::Facts::#{terminus_class_name} < Oregano::Node::Facts::Yaml
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/oregano/indirector/node/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "oregano/indirector/node/yaml"
    class Oregano::Node::#{terminus_class_name} < Oregano::Node::Yaml
      def find(request)
        nil
      end
    end
  ',
}
file { '#{moduledir}/yaml_terminus/lib/oregano/indirector/resource/#{storeconfigs_backend_name}.rb':
  ensure => file,
  content => '
    require "oregano/indirector/yaml"
    require "oregano/resource/catalog"
    class Oregano::Resource::#{terminus_class_name} < Oregano::Indirector::Yaml
      desc "Read resource instances from cached catalogs"
      def search(request)
        catalog_dir = File.join(Oregano.run_mode.master? ? Oregano[:yamldir] : Oregano[:clientyamldir], "catalog", "*")
        results = Dir.glob(catalog_dir).collect { |file|
          catalog = Oregano::Resource::Catalog.convert_from(:pson, File.read(file))
          if catalog.name == request.options[:host]
            next
          end
          catalog.resources.select { |resource|
            resource.type == request.key && resource.exported
          }.map! { |res|
            data_hash = res.to_data_hash
            parameters = data_hash["parameters"].map do |name, value|
              Oregano::Parser::Resource::Param.new(:name => name, :value => value)
            end
            attrs = {:parameters => parameters, :scope => request.options[:scope]}
            result = Oregano::Parser::Resource.new(res.type, res.title, attrs)
            result.collector_id = "\#{catalog.name}|\#{res.type}|\#{res.title}"
            result
          }
        }.flatten.compact
        results
      end
    end
  ',
}
# all the filtering is taken care of in the terminii
#   so any tests on filtering belong with oreganodb or pe
file { '#{environmentpath}/#{tmp_environment}/manifests/site.pp':
  ensure => file,
  content => '
    node "#{master.hostname}" {
      @@user{"#{exported_username}": ensure => present,}
    }
    node "default" {
      # collect resources on all nodes (oregano prevents collection on same node)
      User<<| |>>
    }
  ',
}
MANIFEST
    apply_manifest_on(master, manifest, :catch_failures => true)
  end

  # must specify environment in oregano.conf for it to pickup the terminus code in an environment module
  #   but we have to bounce the server to pickup the storeconfigs... config anyway
  # we can't use with_oregano_running_on here because it uses oregano resource to bounce the server
  #   oregano resource tries to use yaml_storeconfig's path() which doesn't exist
  #   and fails back to yaml which indicates an attempted directory traversal and fails.
  #   we could implemnt path() properly, but i'm just going to start the server the old fashioned way
  #  and... config set is broken and doesn't add a main section
  step 'turn on storeconfigs, start oreganoserver the old fashioned way' do
    on(master, "cp #{File.join(master.oregano['confdir'],'oregano.conf')} #{File.join('','tmp')}")
    on(master, "echo [main] >> #{File.join(master.oregano['confdir'],'oregano.conf')}")
    on(master, "echo environment=#{tmp_environment} >> #{File.join(master.oregano['confdir'],'oregano.conf')}")
    on(master, oregano('config set storeconfigs true --section main'))
    on(master, oregano("config set storeconfigs_backend #{storeconfigs_backend_name} --section main"))
    on(master, "service #{master['oreganoservice']} restart")
    step 'run the master agent to export the resources' do
      on(master, oregano("agent -t --server #{master.hostname} --environment #{tmp_environment}"))
    end
    agents.each do |agent|
      next if agent == master
      step 'run the agents to collect exported resources' do
        on(agent, oregano("agent -t --server #{master.hostname} --environment #{tmp_environment}"),
           :acceptable_exit_codes => 2)
        on(agent, oregano_resource("user #{exported_username}"), :accept_all_exit_codes => true) do |result|
          assert_match(/present/, result.stdout, 'collected resource not found')
        end
      end
    end
  end

end
