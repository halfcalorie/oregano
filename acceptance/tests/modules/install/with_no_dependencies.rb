test_name "oregano module install (with no dependencies)"
require 'oregano/acceptance/module_utils'
extend Oregano::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies = []

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

step "Install a module with no dependencies"
on master, oregano("module install #{module_author}-#{module_name}") do
  assert_module_installed_ui(stdout, module_author, module_name)
end
assert_module_installed_on_disk(master, module_name)
