test_name "Install packages and repositories on target machines..." do
require 'beaker/dsl/install_utils'
extend Beaker::DSL::InstallUtils

  SourcePath  = Beaker::DSL::InstallUtils::SourcePath
  GitURI      = Beaker::DSL::InstallUtils::GitURI
  GitHubSig   = Beaker::DSL::InstallUtils::GitHubSig

  tmp_repositories = []
  options[:install].each do |uri|
    raise(ArgumentError, "Missing GitURI argument. URI is nil.") if uri.nil?
    raise(ArgumentError, "#{uri} is not recognized.") unless(uri =~ GitURI)
    tmp_repositories << extract_repo_info_from(uri)
  end

  repositories = order_packages(tmp_repositories)

  versions = {}
  hosts.each_with_index do |host, index|
    on host, "echo #{GitHubSig} >> $HOME/.ssh/known_hosts"

    repositories.each do |repository|
      step "Install #{repository[:name]}"
      if repository[:path] =~ /^file:\/\/(.+)$/
        on host, "test -d #{SourcePath} || mkdir -p #{SourcePath}"
        source_dir = $1
        checkout_dir = "#{SourcePath}/#{repository[:name]}"
        on host, "rm -f #{checkout_dir}" # just the symlink, do not rm -rf !
        on host, "ln -s #{source_dir} #{checkout_dir}"
        on host, "cd #{checkout_dir} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi"
      else
        oregano_dir = host.tmpdir('oregano')
        on(host, "chmod 755 #{oregano_dir}")

        gemfile_contents = <<END
source '#{ENV["GEM_SOURCE"] || "https://rubygems.org"}'
gem '#{repository[:name]}', :git => '#{repository[:path]}', :ref => '#{ENV['SHA']}'
END
        case host['platform']
        when /windows/
          create_remote_file(host, "#{oregano_dir}/Gemfile", gemfile_contents)
          # bundle must be passed a Windows style path for a binstubs location
          binstubs_dir = on(host, "cygpath -m \"#{host['oreganobindir']}\"").stdout.chomp
          # note passing --shebang to bundle is not useful because Cygwin
          # already finds the Ruby interpreter OK with the standard shebang of:
          # !/usr/bin/env ruby
          # the problem is a Cygwin style path is passed to the interpreter and this can't be modified:
          # http://cygwin.1069669.n5.nabble.com/Pass-windows-style-paths-to-the-interpreter-from-the-shebang-line-td43870.html
          on host, "cd #{oregano_dir} && cmd.exe /c \"bundle install --system --binstubs #{binstubs_dir}\""
          # oregano.bat isn't written by Bundler, but facter.bat is - copy this generic file
          on host, "cd #{host['oreganobindir']} && test -f ./oregano.bat || cp ./facter.bat ./oregano.bat"
          # to access gem / facter / oregano / bundle / irb with Cygwin generally requires aliases
          # so that commands in /usr/bin are overridden and the binstub wrappers won't run inside Cygwin
          # but rather will execute as batch files through cmd.exe
          # without being overridden, Cygwin reads the shebang and causes errors like:
          # C:\cygwin64\bin\ruby.exe: No such file or directory -- /usr/bin/oregano (LoadError)
          # NOTE /usr/bin/oregano is a Cygwin style path that our custom Ruby build
          # does not understand - it expects a standard Windows path like c:\cygwin64\bin\oregano

          # a workaround in interactive SSH is to add aliases to local session / .bashrc:
          #   on host, "echo \"alias oregano='C:/\\cygwin64/\\bin/\\oregano.bat'\" >> ~/.bashrc"
          # note that this WILL NOT impact Beaker runs though
          oregano_bundler_install_dir = on(host, "cd #{oregano_dir} && cmd.exe /c bundle show oregano").stdout.chomp
        when /el-7/
          gemfile_contents = gemfile_contents + "gem 'json'\n"
          create_remote_file(host, "#{oregano_dir}/Gemfile", gemfile_contents)
          on host, "cd #{oregano_dir} && bundle install --system --binstubs #{host['oreganobindir']}"
          oregano_bundler_install_dir = on(host, "cd #{oregano_dir} && bundle show oregano").stdout.chomp
        when /solaris/
          create_remote_file(host, "#{oregano_dir}/Gemfile", gemfile_contents)
          on host, "cd #{oregano_dir} && bundle install --system --binstubs #{host['oreganobindir']} --shebang #{host['oreganobindir']}/ruby"
          oregano_bundler_install_dir = on(host, "cd #{oregano_dir} && bundle show oregano").stdout.chomp
        else
          create_remote_file(host, "#{oregano_dir}/Gemfile", gemfile_contents)
          on host, "cd #{oregano_dir} && bundle install --system --binstubs #{host['oreganobindir']}"
          oregano_bundler_install_dir = on(host, "cd #{oregano_dir} && bundle show oregano").stdout.chomp
        end

        # install.rb should also be called from the Oregano gem install dir
        # this is required for the oreganores.dll event log dll on Windows
        on host, "cd #{oregano_bundler_install_dir} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi"
      end
    end
  end

  step "Hosts: create basic oregano.conf" do
    hosts.each do |host|
      confdir = host.oregano['confdir']
      on host, "mkdir -p #{confdir}"
      oreganoconf = File.join(confdir, 'oregano.conf')

      if host['roles'].include?('agent')
        on host, "echo '[agent]' > '#{oreganoconf}' && " +
                 "echo server=#{master} >> '#{oreganoconf}'"
      else
        on host, "touch '#{oreganoconf}'"
      end
    end
  end

  step "Hosts: create environments directory like AIO does" do
    hosts.each do |host|
      codedir = host.oregano['codedir']
      on host, "mkdir -p #{codedir}/environments/production/manifests"
      on host, "mkdir -p #{codedir}/environments/production/modules"
      on host, "chmod -R 755 #{codedir}"
    end
  end
end
