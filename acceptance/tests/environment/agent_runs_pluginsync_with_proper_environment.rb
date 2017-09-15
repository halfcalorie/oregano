# We noticed some strange behavior if an environment was changed between the
# time where the node retrieved facts for itself and the catalog retrieved
# facts oregano could pluginsync with the incorrect environment. For more
# details see PUP-3591.
test_name "Agent should pluginsync with the environment the agent resolves to"

tag 'audit:high',
    'audit:integration',
    'audit:refactor',  # Inquire as to whether this is still a risk with oregano 5+
                       # Use mk_temp_environment_with_teardown helper
    'server'

testdir = create_tmpdir_for_user master, 'environment_resolve'

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['privatebindir']}/ruby
filename = '#{testdir}/enc.lock'
if !File.exists?(filename)
  puts "environment: production"
  f = File.new(filename, 'w')
  f.write("locked")
  f.close()
else
  puts "environment: correct"
end
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
    '#{testdir}/environments/correct/':;
    '#{testdir}/environments/correct/modules':;
    '#{testdir}/environments/correct/modules/amod':;
    '#{testdir}/environments/correct/modules/amod/lib':;
    '#{testdir}/environments/correct/modules/amod/lib/oregano':;
  }
  file { '#{testdir}/environments/correct/modules/amod/lib/oregano/foo.rb':
    ensure => file,
    mode => "0640",
    content => "#correct_version",
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
    on(agent, oregano("agent", "-t", "--server #{master}"))
    on(agent, "cat \"#{agent.oregano['vardir']}/lib/oregano/foo.rb\"")
    assert_match(/#correct_version/, stdout, "The plugin from environment 'correct' was not synced")
    on(agent, "rm -rf \"#{agent.oregano['vardir']}/lib\"")
  end
end
