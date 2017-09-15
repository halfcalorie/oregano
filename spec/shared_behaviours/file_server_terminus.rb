#! /usr/bin/env ruby
shared_examples_for "Oregano::Indirector::FileServerTerminus" do
  # This only works if the shared behaviour is included before
  # the 'before' block in the including context.
  before do
    Oregano::FileServing::Configuration.instance_variable_set(:@configuration, nil)
    Oregano::FileSystem.stubs(:exist?).returns true
    Oregano::FileSystem.stubs(:exist?).with(Oregano[:fileserverconfig]).returns(true)

    @path = Tempfile.new("file_server_testing")
    path = @path.path
    @path.close!
    @path = path

    Dir.mkdir(@path)
    File.open(File.join(@path, "myfile"), "w") { |f| f.print "my content" }

    # Use a real mount, so the integration is a bit deeper.
    @mount1 = Oregano::FileServing::Configuration::Mount::File.new("one")
    @mount1.path = @path

    @parser = stub 'parser', :changed? => false
    @parser.stubs(:parse).returns("one" => @mount1)

    Oregano::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

    # Stub out the modules terminus
    @modules = mock 'modules terminus'

    @request = Oregano::Indirector::Request.new(:indirection, :method, "oregano://myhost/one/myfile", nil)
  end

  it "should use the file server configuration to find files" do
    @modules.stubs(:find).returns(nil)
    @terminus.indirection.stubs(:terminus).with(:modules).returns(@modules)

    path = File.join(@path, "myfile")

    expect(@terminus.find(@request)).to be_instance_of(@test_class)
  end
end
