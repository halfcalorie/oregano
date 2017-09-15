test_name "oregano module upgrade (with scattered dependencies)"
require 'oregano/acceptance/module_utils'
extend Oregano::Acceptance::ModuleUtils
require 'oregano/acceptance/environment_utils'
extend Oregano::Acceptance::EnvironmentUtils

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

fq_prod_env_modpath = "#{environmentpath}/production/modules"

stub_forge_on(master)

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'
on master, oregano("module install pmtacceptance-stdlub --version 0.0.2 --target-dir #{fq_prod_env_modpath}")
on master, oregano("module install pmtacceptance-java --version 1.6.0 --target-dir #{master['distmoduledir']} --ignore-dependencies")
on master, oregano("module install pmtacceptance-postql --version 0.0.1 --target-dir #{master['distmoduledir']} --ignore-dependencies")
on master, oregano("module list") do
  assert_match /pmtacceptance-java.*1\.6\.0/, stdout, 'Could not find pmtacceptance/java'
  assert_match /pmtacceptance-postql.*0\.0\.1/, stdout, 'Could not find pmtacceptance/postql'
  assert_match /pmtacceptance-stdlub.*0\.0\.2/, stdout, 'Could not find pmtacceptance/stdlub'
end
