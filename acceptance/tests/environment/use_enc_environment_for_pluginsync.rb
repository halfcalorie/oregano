test_name "Agent should use environment given by ENC for pluginsync"

tag 'audit:medium',
    'audit:integration',
    'audit:refactor',    # This test should be rolled into use_enc_environment
    'server'

testdir = create_tmpdir_for_user master, 'respect_enc_test'

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['privatebindir']}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => "0770",
    owner => #{master.oregano['user']},
    group => #{master.oregano['group']},
  }
  file {
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/special/':;
    '#{testdir}/environments/special/modules':;
    '#{testdir}/environments/special/modules/amod':;
    '#{testdir}/environments/special/modules/amod/lib':;
    '#{testdir}/environments/special/modules/amod/lib/oregano':;
  }
  file { '#{testdir}/environments/special/modules/amod/lib/oregano/foo.rb':
    ensure => file,
    mode => "0640",
    content => "#special_version",
  }
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  },
  'master' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb"
  },
}

with_oregano_running_on master, master_opts, testdir do

  agents.each do |agent|
    agent_vardir = agent.oregano['vardir']
    teardown do
      on agent, "rm -rf \"#{agent_vardir}/lib\""
    end

    run_agent_on(agent, "--no-daemonize --onetime --server #{master}")
    on agent, "cat \"#{agent_vardir}/lib/oregano/foo.rb\""
    assert_match(/#special_version/, stdout, "The plugin from environment 'special' was not synced")
  end
end
