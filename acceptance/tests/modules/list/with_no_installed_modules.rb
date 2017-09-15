test_name "oregano module list (with no installed modules)"

tag 'audit:low',
    'audit:unit'

step "List the installed modules"
modulesdir = master.tmpdir('oregano_module')
on master, oregano("module list --modulepath #{modulesdir}") do
  assert_match(/no modules installed/, stdout,
        "Declaration of 'no modules installed' not found")
end
