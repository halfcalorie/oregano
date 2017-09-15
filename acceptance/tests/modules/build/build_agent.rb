test_name "oregano module build (agent)"

tag 'audit:medium',
    'audit:acceptance'

agents.each do |agent|
  teardown do
    on agent, 'rm -rf bar'
  end

  step 'setup: ensure clean working directory'
  on agent, 'rm -rf bar'

  step 'generate'
  on(agent, oregano('module generate foo-bar --skip-interview'))

  step 'build'
  on(agent, oregano('module build bar')) do
    assert_match(/Module built: .*\/bar\/pkg\/foo-bar-.*\.tar\.gz/, stdout) unless agent['locale'] == 'ja'
  end
end
