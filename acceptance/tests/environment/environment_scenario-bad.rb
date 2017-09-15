test_name 'Test behavior of directory environments when environmentpath is set to a non-existent directory'
require 'oregano/acceptance/environment_utils'
extend Oregano::Acceptance::EnvironmentUtils
require 'oregano/acceptance/classifier_utils'
extend Oregano::Acceptance::ClassifierUtils

tag 'audit:medium',
    'audit:unit',  # The error responses for the agent should be covered by Ruby unit tests.
                   # The server 404/400 response should be covered by server integration tests.
    'server'


classify_nodes_as_agent_specified_if_classifer_present

step 'setup environments'

stub_forge_on(master)

testdir = create_tmpdir_for_user master, 'confdir'
oregano_conf_backup_dir = create_tmpdir_for_user(master, "oregano-conf-backup-dir")

apply_manifest_on(master, environment_manifest(testdir), :catch_failures => true)

step  'Test'
env_path = '/doesnotexist'
master_opts = {
  'main' => {
    'environmentpath' => "#{env_path}",
  }
}
env = 'testing'

results = use_an_environment(env, 'bad environmentpath', master_opts, testdir, oregano_conf_backup_dir, :directory_environments => true)

expectations = {
  :oregano_config => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{env_path}}],
  },
  :oregano_module_install => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{env_path}}],
  },
  :oregano_module_uninstall => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{env_path}}],
  },
  :oregano_apply => {
    :exit_code => 1,
    :matches => [%r{Could not find a directory environment named '#{env}' anywhere in the path.*#{env_path}}],
  },
  :oregano_agent => {
    :exit_code => 1,
  },
}

agents.each do |host|
  unless host['locale'] == 'ja'
    expectations[:oregano_agent][:matches] = [%r{(Warning|Error).*(404|400).*Could not find environment '#{env}'},
                                             %r{Could not retrieve catalog; skipping run}]
  end
end

assert_review(review_results(results,expectations))
