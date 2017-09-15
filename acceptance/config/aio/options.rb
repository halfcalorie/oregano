{
  :type                        => 'aio',
  :pre_suite                   => [
    'setup/common/pre-suite/000-delete-oregano-when-none.rb',
    'setup/aio/pre-suite/010_Install.rb',
    'setup/aio/pre-suite/020_InstallCumulusModules.rb',
    'setup/aio/pre-suite/021_InstallAristaModule.rb',
    'setup/common/pre-suite/025_StopFirewall.rb',
    'setup/common/pre-suite/040_ValidateSignCert.rb',
    'setup/aio/pre-suite/045_EnsureMasterStarted.rb',
  ],
  'is_oreganoserver'            => true,
  'use-service'                => true, # use service scripts to start/stop stuff
  'oreganoservice'              => 'oreganoserver',
  'oreganoserver-confdir'       => '/etc/oreganolabs/oreganoserver/conf.d',
  'oreganoserver-config'        => '/etc/oreganolabs/oreganoserver/conf.d/oreganoserver.conf'
}.merge(eval File.read('config/common/options.rb'))
