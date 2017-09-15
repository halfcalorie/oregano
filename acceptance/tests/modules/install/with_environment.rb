test_name 'oregano module install (with environment)'
require 'oregano/acceptance/module_utils'
extend Oregano::Acceptance::ModuleUtils

tag 'audit:low',       # Install via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

tmpdir = master.tmpdir('module-install-with-environment')

module_author = "pmtacceptance"
module_name   = "nginx"

orig_installed_modules = get_installed_modules_for_hosts hosts
teardown do
  rm_installed_modules_from_hosts orig_installed_modules, (get_installed_modules_for_hosts hosts)
end

step 'Setup'

stub_forge_on(master)

oregano_conf = generate_base_directory_environments(tmpdir)

check_module_install_in = lambda do |environment_path, module_install_args|
  on(master, oregano("module install #{module_author}-#{module_name} --config=#{oregano_conf} #{module_install_args}")) do
    assert_module_installed_ui(stdout, module_author, module_name)
    assert_match(/#{environment_path}/, stdout,
          "Notice of non default install path was not displayed")
  end
  assert_module_installed_on_disk(master, module_name, environment_path)
end

step 'Install a module into a non default directory environment' do
  check_module_install_in.call("#{tmpdir}/environments/direnv/modules",
                              "--environment=direnv")
end

step 'Prepare a separate modulepath'
modulepath_dir = master.tmpdir("modulepath")
apply_manifest_on(master, <<-MANIFEST , :catch_failures => true)
  file {
    [
      '#{tmpdir}/environments/production',
      '#{modulepath_dir}',
    ]:

    ensure => directory,
    owner => #{master.oregano['user']},
  }
MANIFEST

step "Install a module into --modulepath #{modulepath_dir} despite the implicit production directory env existing" do
  check_module_install_in.call(modulepath_dir, "--modulepath=#{modulepath_dir}")
end

step "Uninstall so we can try a different scenario" do
  on(master, oregano("module uninstall #{module_author}-#{module_name} --config=#{oregano_conf} --modulepath=#{modulepath_dir}"))
end

step "Install a module into --modulepath #{modulepath_dir} with a directory env specified" do
  check_module_install_in.call(modulepath_dir,
                               "--modulepath=#{modulepath_dir} --environment=direnv")
end
