test_name "node_name_fact should be used to determine the node name for oregano agent"

tag 'audit:medium',
    'audit:integration',  # Tests that the server properly overrides certname with node_name fact.
                          # Testing of passenger master is no longer needed.
    'server'

success_message = "node_name_fact setting was correctly used to determine the node name"

testdir = master.tmpdir("nodenamefact")
node_names = []

on agents, facter('kernel') do
  node_names << stdout.chomp
end

node_names.uniq!

if @options[:is_oreganoserver]
  step "Prepare for custom tk-auth rules" do
    on master, 'cp /etc/oreganolabs/oreganoserver/conf.d/auth.conf /etc/oreganolabs/oreganoserver/conf.d/auth.bak'
    modify_tk_config(master, options['oreganoserver-config'], {'jruby-oregano' => {'use-legacy-auth-conf' => false}})
  end

  teardown do
    modify_tk_config(master, options['oreganoserver-config'], {'jruby-oregano' => {'use-legacy-auth-conf' => true}})
    on master, 'cp /etc/oreganolabs/oreganoserver/conf.d/auth.bak /etc/oreganolabs/oreganoserver/conf.d/auth.conf'
  end

  step "Setup tk-auth rules" do
    tka_header = <<-HEADER
authorization: {
    version: 1
    rules: [
        {
            match-request: {
                path: "/oregano/v3/file"
                type: path
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs file"
        },
    HEADER

    tka_node_rules = node_names.map do |node_name|
      <<-NODE_RULES
        {
            match-request: {
                path: "/oregano/v3/catalog/#{node_name}"
                type: path
                method: [get, post]
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs catalog #{node_name}"
        },
        {
            match-request: {
                path: "/oregano/v3/node/#{node_name}"
                type: path
                method: get
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs node #{node_name}"
        },
        {
            match-request: {
                path: "/oregano/v3/report/#{node_name}"
                type: path
                method: put
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs report #{node_name}"
        },
      NODE_RULES
    end

    tka_footer = <<-FOOTER
        {
          match-request: {
            path: "/"
            type: path
          }
          deny: "*"
          sort-order: 999
          name: "oreganolabs deny all"
        }
    ]
}
    FOOTER

    tk_auth = [tka_header, tka_node_rules, tka_footer].flatten.join("\n")

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
      file { '/etc/oreganolabs/oreganoserver/conf.d/auth.conf':
        ensure => file,
        mode => '0644',
        content => '#{tk_auth}',
      }
    MANIFEST
  end
else
  step "Setup legacy auth.conf rules" do
    authfile = "#{testdir}/auth.conf"
    authconf = node_names.map do |node_name|
      <<-AUTHCONF
path /oregano/v3/catalog/#{node_name}
auth yes
allow *

path /oregano/v3/node/#{node_name}
auth yes
allow *

path /oregano/v3/report/#{node_name}
auth yes
allow *
      AUTHCONF
    end.join("\n")

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
    file { '#{authfile}':
      ensure => file,
      mode => '0644',
      content => '#{authconf}',
    }
    MANIFEST
  end
end

step "Setup site.pp for node name based classification" do

  site_manifest = <<-SITE_MANIFEST
node default {
  notify { "false": }
}

node #{node_names.map { |name| %Q["#{name}"] }.join(", ")} {
  notify { "#{success_message}": }
}
SITE_MANIFEST

  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
    $directories = [
      '#{testdir}',
      '#{testdir}/environments',
      '#{testdir}/environments/production',
      '#{testdir}/environments/production/manifests',
    ]

    file { $directories:
      ensure => directory,
      mode => '0755',
    }

    file { '#{testdir}/environments/production/manifests/manifest.pp':
      ensure => file,
      mode => '0644',
      content => '#{site_manifest}',
    }
  MANIFEST
end

step "Ensure nodes are classified based on the node name fact" do
  master_opts = {
    'main' => {
      'environmentpath' => "#{testdir}/environments",
    },
    'master' => {
      'rest_authconfig' => "#{testdir}/auth.conf",
      'node_terminus'   => 'plain',
    },
  }

  with_oregano_running_on(master, master_opts, testdir) do
    on(agents, oregano('agent', "--no-daemonize --verbose --onetime --node_name_fact kernel --server #{master}")) do
      assert_match(/defined 'message'.*#{success_message}/, stdout)
    end
  end
end
