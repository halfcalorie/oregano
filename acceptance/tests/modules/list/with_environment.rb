test_name 'oregano module list (with environment)'
require 'oregano/acceptance/module_utils'
extend Oregano::Acceptance::ModuleUtils

tmpdir = master.tmpdir('module-list-with-environment')

step 'Setup'

stub_forge_on(master)

oregano_conf = generate_base_directory_environments(tmpdir)

step 'List modules in a non default directory environment' do
  on master, oregano("module", "install",
                    "pmtacceptance-nginx",
                    "--config", oregano_conf,
                    "--environment=direnv")

  on master, oregano("module", "list",
                    "--config", oregano_conf,
                    "--environment=direnv") do

    assert_match(%r{#{tmpdir}/environments/direnv/modules}, stdout)
    assert_match(/pmtacceptance-nginx/, stdout)
  end
end
