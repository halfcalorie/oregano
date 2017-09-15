require 'oregano/acceptance/common_utils'
require 'oregano/acceptance/install_utils'

extend Oregano::Acceptance::InstallUtils

test_name "Install Packages"

step "Install oregano-agent..." do
  opts = {
    :oregano_collection    => 'PC1',
    :oregano_agent_sha     => ENV['SHA'],
    # SUITE_VERSION is necessary for Beaker to build a package download
    # url which is built upon a `git describe` for a SHA.
    # Beaker currently cannot find or calculate this value based on
    # the SHA, and thus it must be passed at invocation time.
    # The one exception is when SHA is a tag like `1.8.0` and
    # SUITE_VERSION will be equivalent.
    # RE-8333 may make this unnecessary in the future
    :oregano_agent_version => ENV['SUITE_VERSION'] || ENV['SHA']
  }
  agents.each do |agent|
    next if agent == master # Avoid SERVER-528
    install_oregano_agent_dev_repo_on(agent, opts)
  end
end

MASTER_PACKAGES = {
  :redhat => [
    'oreganoserver',
  ],
  :debian => [
    'oreganoserver',
  ],
}

step "Install oreganoserver..." do
  if master[:hypervisor] == 'ec2'
    if master[:platform].match(/(?:el|centos|oracle|redhat|scientific)/)
      # An EC2 master instance does not have access to oreganolabs.net for getting
      # dev repos.
      #
      # We will install the appropriate repo to satisfy the oreganoserver requirement
      # and then upgrade oregano-agent with the targeted SHA package afterwards.
      #
      # Currently, only an `el` master is supported for this operation.
      if ENV['SERVER_VERSION']
        variant, version = master['platform'].to_array
        if ENV['SERVER_VERSION'].to_i < 5
          logger.info "EC2 master found: Installing nightly build of oregano-agent repo to satisfy oreganoserver dependency."
          on(master, "rpm -Uvh https://yum.oreganolabs.com/oreganolabs-release-pc1-el-#{version}.noarch.rpm")
        else
          logger.info "EC2 master found: Installing nightly build of oregano-agent repo to satisfy oreganoserver dependency."
          on(master, "rpm -Uvh https://yum.oreganolabs.com/oregano5-release-el-#{version}.noarch.rpm")
        end
      else
        logger.info "EC2 master found: Installing nightly build of oregano-agent repo to satisfy oreganoserver dependency."
        install_repos_on(master, 'oregano-agent', 'nightly', 'repo-configs')
        install_repos_on(master, 'oreganoserver', 'nightly', 'repo-configs')
      end

      master.install_package('oreganoserver')

      logger.info "EC2 master found: Installing #{ENV['SHA']} build of oregano-agent."
      # Upgrade installed oregano-agent with targeted SHA.
      opts = {
        :oregano_collection => 'PC1',
        :oregano_agent_sha => ENV['SHA'],
        :oregano_agent_version => ENV['SUITE_VERSION'] || ENV['SHA'] ,
        :dev_builds_url => "http://builds.delivery.oreganolabs.net"
      }

      copy_dir_local = File.join('tmp', 'repo_configs', master['platform'])
      release_path_end, release_file = master.oregano_agent_dev_package_info( opts[:oregano_collection], opts[:oregano_agent_version], opts)
      release_path = "#{opts[:dev_builds_url]}/oregano-agent/#{opts[:oregano_agent_sha]}/repos/"
      release_path << release_path_end
      fetch_http_file(release_path, release_file, copy_dir_local)
      scp_to master, File.join(copy_dir_local, release_file), master.external_copy_base
      on master, "rpm -Uvh #{File.join(master.external_copy_base, release_file)} --oldpackage --force"
    else
      fail_test("EC2 master found, but it was not an `el` host: The specified `oregano-agent` build (#{ENV['SHA']}) cannot be installed.")
    end
  else
    if ENV['SERVER_VERSION'].nil? || ENV['SERVER_VERSION'] == 'latest'
      server_version = 'latest'
      server_download_url = "http://nightlies.oregano.com"
    else
      server_version = ENV['SERVER_VERSION']
      server_download_url = "http://builds.delivery.oreganolabs.net"
    end
    install_oreganolabs_dev_repo(master, 'oreganoserver', server_version, nil, :dev_builds_url => server_download_url)
    install_oreganolabs_dev_repo(master, 'oregano-agent', ENV['SHA'])
    master.install_package('oreganoserver')
  end
end

# make sure install is sane, beaker has already added oregano and ruby
# to PATH in ~/.ssh/environment
agents.each do |agent|
  on agent, oregano('--version')
  ruby = Oregano::Acceptance::CommandUtils.ruby_command(agent)
  on agent, "#{ruby} --version"
end

# Get a rough estimate of clock skew among hosts
times = []
hosts.each do |host|
  ruby = Oregano::Acceptance::CommandUtils.ruby_command(host)
  on(host, "#{ruby} -e 'puts Time.now.strftime(\"%Y-%m-%d %T.%L %z\")'") do |result|
    times << result.stdout.chomp
  end
end
times.map! do |time|
  (Time.strptime(time, "%Y-%m-%d %T.%L %z").to_f * 1000.0).to_i
end
diff = times.max - times.min
if diff < 60000
  logger.info "Host times vary #{diff} ms"
else
  logger.warn "Host times vary #{diff} ms, tests may fail"
end

configure_gem_mirror(hosts)
