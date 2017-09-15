{
  :type                        => :git,
  :install                     => [
    'oregano',
  ],
  :pre_suite                   => [
    'setup/common/pre-suite/000-delete-oregano-when-none.rb',
    'setup/git/pre-suite/000_EnvSetup.rb',
    'setup/git/pre-suite/010_TestSetup.rb',
    'setup/git/pre-suite/020_OreganoUserAndGroup.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/git/pre-suite/030_OreganoMasterSanity.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/git/pre-suite/060_InstallModules.rb',
    'setup/git/pre-suite/070_InstallCACerts.rb',
  ],
}.merge(eval File.read('config/common/options.rb'))
