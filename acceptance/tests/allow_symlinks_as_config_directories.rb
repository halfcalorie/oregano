test_name "Should allow symlinks to directories as configuration directories"

tag 'audit:low',
    'audit:acceptance'  # Need to cover risk of OS/ruby symlink behavior (OSX, Solaris).

confine :except, :platform => 'windows'

agents.each do |agent|
  step "Create the test confdir with a link to it"
  confdir = agent.tmpdir('oregano_conf-directory')
  conflink = agent.tmpfile('oregano_conf-symlink')

  on agent, "rm -rf #{conflink} #{confdir}"

  on agent, "mkdir #{confdir}"
  on agent, "ln -s #{confdir} #{conflink}"

  on(agent, oregano('config', 'set', 'certname', 'awesome_certname', '--confdir', confdir))

  manifest = 'notify{"My certname is $clientcert": }'

  step "Run Oregano and ensure it used the conf file in the confdir"
  on agent, oregano_apply("--confdir #{conflink}"), :stdin => manifest do
    assert_match(/My certname is awesome_certname[^\w]/, stdout)
  end

  step "Check that the symlink and confdir are unchanged"
  on agent, "[ -L #{conflink} ]"
  on agent, "[ -d #{confdir} ]"
  if agent[:platform] =~ /solaris|aix/
    on agent, "[ $(ls -ld #{conflink} | sed 's/.*-> //') = #{confdir} ]"
  else
    on agent, "[ $(readlink #{conflink}) = #{confdir} ]"
  end
end
