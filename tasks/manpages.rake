# require 'fileutils'

desc "Build Oregano manpages"
task :gen_manpages do
  require 'oregano/face'
  require 'fileutils'

  # TODO: this line is unfortunate.  In an ideal world, faces would serve
  #  as a clear, well-defined entry-point into the code and could be
  #  responsible for state management all on their own; this really should
  #  not be necessary.  When we can, we should get rid of it.
  #  --cprice 2012-05-16
  Oregano.initialize_settings()

  helpface = Oregano::Face[:help, '0.0.1']
  manface  = Oregano::Face[:man, '0.0.1']

  sbins = Dir.glob(%w{sbin/*})
  bins  = Dir.glob(%w{bin/*})
  non_face_applications = helpface.legacy_applications
  faces = Oregano::Face.faces.map(&:to_s)
  apps = non_face_applications + faces

  ronn_args = '--manual="Oregano manual" --organization="Oregano Labs, LLC" -r'

  # Locate ronn
  ronn = %x{which ronn}.chomp
  unless File.executable?(ronn) then fail("Ronn does not appear to be installed.") end

#   def write_manpage(text, filename)
#     IO.popen("#{ronn} #{ronn_args} -r > #{filename}") do |fh| fh.write text end
#   end

  # Create oregano.conf.5 man page
#   IO.popen("#{ronn} #{ronn_args} > ./man/man5/oregano.conf.5", 'w') do |fh|
#     fh.write %x{RUBYLIB=./lib:$RUBYLIB bin/oreganodoc --reference configuration}
#   end
  %x{RUBYLIB=./lib:$RUBYLIB bin/oregano doc --reference configuration > ./man/man5/oreganoconf.5.ronn}
  %x{#{ronn} #{ronn_args} ./man/man5/oreganoconf.5.ronn}
  FileUtils.mv("./man/man5/oreganoconf.5", "./man/man5/oregano.conf.5")
  FileUtils.rm("./man/man5/oreganoconf.5.ronn")

  # Create LEGACY binary man pages (i.e. delete me for 2.8.0)
  binary = bins + sbins
  binary.each do |bin|
    b = bin.gsub( /^s?bin\//, "")
    %x{RUBYLIB=./lib:$RUBYLIB #{bin} --help > ./man/man8/#{b}.8.ronn}
    %x{#{ronn} #{ronn_args} ./man/man8/#{b}.8.ronn}
    FileUtils.rm("./man/man8/#{b}.8.ronn")
  end

  # Create regular non-face man pages
  non_face_applications.each do |app|
    %x{RUBYLIB=./lib:$RUBYLIB bin/oregano #{app} --help > ./man/man8/oregano-#{app}.8.ronn}
    %x{#{ronn} #{ronn_args} ./man/man8/oregano-#{app}.8.ronn}
    FileUtils.rm("./man/man8/oregano-#{app}.8.ronn")
  end

  # Create face man pages
  faces.each do |face|
    File.open("./man/man8/oregano-#{face}.8.ronn", 'w') do |fh|
      fh.write manface.man("#{face}")
    end

    %x{#{ronn} #{ronn_args} ./man/man8/oregano-#{face}.8.ronn}
    FileUtils.rm("./man/man8/oregano-#{face}.8.ronn")
  end

  # Delete orphaned manpages if binary was deleted
  Dir.glob(%w{./man/man8/oregano-*.8}) do |app|
    appname = app.match(/oregano-(.*)\.8/)[1]
    FileUtils.rm("./man/man8/oregano-#{appname}.8") unless apps.include?(appname)
  end

  # Vile hack: create oregano resource man page
  # Currently, the useless resource face wins against oregano resource in oregano
  # man. (And actually, it even gets removed from the list of legacy
  # applications.) So we overwrite it with the correct man page at the end.
  %x{RUBYLIB=./lib:$RUBYLIB bin/oregano resource --help > ./man/man8/oregano-resource.8.ronn}
  %x{#{ronn} #{ronn_args} ./man/man8/oregano-resource.8.ronn}
  FileUtils.rm("./man/man8/oregano-resource.8.ronn")

end
