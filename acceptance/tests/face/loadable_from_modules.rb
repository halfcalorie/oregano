test_name "Exercise loading a face from a module"

# Because the module tool does not work on windows, we can't run this test there
confine :except, :platform => 'windows'
confine :except, :platform => /centos-4|el-4/ # PUP-5226

tag 'audit:medium',
    'audit:acceptance',    # This has been OS sensitive.
    'audit:refactor'       # Remove the confine against windows and refactor to
                           # accommodate the Windows platform.

require 'oregano/acceptance/temp_file_utils'
extend Oregano::Acceptance::TempFileUtils
initialize_temp_dirs

agents.each do |agent|
  environmentpath = get_test_file_path(agent, 'environments')
  dev_modulepath = "#{environmentpath}/dev/modules"

  # make sure that we use the modulepath from the dev environment
  oreganoconf = get_test_file_path(agent, 'oregano.conf')
  on agent, oregano("config", "set", "environmentpath", environmentpath, "--section", "main", "--config", oreganoconf)
  on agent, oregano("config", "set", "environment", "dev", "--section", "user", "--config", oreganoconf)

  on agent, 'rm -rf helloworld'
  on agent, oregano("module", "generate", "oreganolabs-helloworld", "--skip-interview")
  mkdirs agent, 'helloworld/lib/oregano/application'
  mkdirs agent, 'helloworld/lib/oregano/face'

  # copy application, face, and utility module
  create_remote_file(agent, "helloworld/lib/oregano/application/helloworld.rb", <<'EOM')
require 'oregano/face'
require 'oregano/application/face_base'

class Oregano::Application::Helloworld < Oregano::Application::FaceBase
end
EOM

  create_remote_file(agent, "helloworld/lib/oregano/face/helloworld.rb", <<'EOM')
Oregano::Face.define(:helloworld, '0.1.0') do
  summary "Hello world face"
  description "This is the hello world face"

  action 'actionprint' do
    summary "Prints hello world from an action"
    when_invoked do |options|
      puts "Hello world from an action"
    end
  end

  action 'moduleprint' do
    summary "Prints hello world from a required module"
    when_invoked do |options|
      require 'oregano/helloworld.rb'
      Oregano::Helloworld.print
    end
  end
end
EOM

  create_remote_file(agent, "helloworld/lib/oregano/helloworld.rb", <<'EOM')
module Oregano::Helloworld
  def print
    puts "Hello world from a required module"
  end
  module_function :print
end
EOM

  on agent, oregano('module', 'build', 'helloworld')
  on agent, oregano('module', 'install', '--ignore-dependencies', '--target-dir', dev_modulepath, 'helloworld/pkg/oreganolabs-helloworld-0.1.0.tar.gz')

  on(agent, oregano('help', '--config', oreganoconf)) do
    assert_match(/helloworld\s*Hello world face/, stdout, "Face missing from list of available subcommands")
  end

  on(agent, oregano('help', 'helloworld', '--config', oreganoconf)) do
    assert_match(/This is the hello world face/, stdout, "Descripion help missing")
    assert_match(/moduleprint\s*Prints hello world from a required module/, stdout, "help for moduleprint action missing")
    assert_match(/actionprint\s*Prints hello world from an action/, stdout, "help for actionprint action missing")
  end

  on(agent, oregano('helloworld', 'actionprint', '--config', oreganoconf)) do
    assert_match(/^Hello world from an action$/, stdout, "face did not print hello world")
  end

  on(agent, oregano('helloworld', 'moduleprint', '--config', oreganoconf)) do
    assert_match(/^Hello world from a required module$/, stdout, "face did not load module to print hello world")
  end
end
