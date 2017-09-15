test_name "Install oregano gem"

require 'oregano/acceptance/common_utils'

agents.each do |agent|
  sha = ENV['SHA']
  base_url = "http://builds.oreganolabs.lan/oregano/#{sha}/artifacts"

  ruby_command = Oregano::Acceptance::CommandUtils.ruby_command(agent)
  gem_command = Oregano::Acceptance::CommandUtils.gem_command(agent)

  # retrieve the build data, since the gem version is based on the short git
  # describe, not the full git SHA
  on(agent, "curl -s -o build_data.yaml #{base_url}/#{sha}.yaml")
  gem_version = on(agent, "#{ruby_command} -ryaml -e 'puts YAML.load_file(\"build_data.yaml\")[:gemversion]'").stdout.chomp

  if agent['platform'] =~ /windows/
    # wipe existing gems first
    default_dir = on(agent, "#{ruby_command} -rrbconfig -e 'puts Gem.default_dir'").stdout.chomp
    on(agent, "rm -rf '#{default_dir}'")

    arch = agent[:ruby_arch] || 'x86'
    gem_arch = arch == 'x64' ? 'x64-mingw32' : 'x86-mingw32'
    url = "#{base_url}/oregano-#{gem_version}-#{gem_arch}.gem"
  else
    url = "#{base_url}/oregano-#{gem_version}.gem"
  end

  step "Download oregano gem from #{url}"
  on(agent, "curl -s -o oregano.gem #{url}")

  step "Install oregano.gem"
  on(agent, "#{gem_command} install oregano.gem")

  step "Verify it's sane"
  on(agent, oregano('--version'))
  on(agent, oregano('apply', "-e \"notify { 'hello': }\"")) do |result|
    assert_match(/defined 'message' as 'hello'/, result.stdout)
  end
end
