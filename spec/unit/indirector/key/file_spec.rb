#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/key/file'

describe Oregano::SSL::Key::File do
  it "should have documentation" do
    expect(Oregano::SSL::Key::File.doc).to be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Oregano[:privatekeydir] = File.expand_path("/key/dir")
    expect(Oregano::SSL::Key::File.collection_directory).to eq(Oregano[:privatekeydir])
  end

  it "should store the ca key at the :cakey location" do
    Oregano.settings.stubs(:use)
    Oregano[:cakey] = File.expand_path("/ca/key")
    file = Oregano::SSL::Key::File.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Oregano[:cakey])
  end

  describe "when choosing the path for the public key" do
    it "should use the :capub setting location if the key is for the certificate authority" do
      Oregano[:capub] = File.expand_path("/ca/pubkey")
      Oregano.settings.stubs(:use)

      @searcher = Oregano::SSL::Key::File.new
      @searcher.stubs(:ca?).returns true
      expect(@searcher.public_key_path("whatever")).to eq(Oregano[:capub])
    end

    it "should use the host name plus '.pem' in :publickeydir for normal hosts" do
      Oregano[:privatekeydir] = File.expand_path("/private/key/dir")
      Oregano[:publickeydir] = File.expand_path("/public/key/dir")
      Oregano.settings.stubs(:use)

      @searcher = Oregano::SSL::Key::File.new
      @searcher.stubs(:ca?).returns false
      expect(@searcher.public_key_path("whatever")).to eq(File.expand_path("/public/key/dir/whatever.pem"))
    end
  end

  describe "when managing private keys" do
    before do
      @searcher = Oregano::SSL::Key::File.new

      @private_key_path = File.join("/fake/key/path")
      @public_key_path = File.join("/other/fake/key/path")

      @searcher.stubs(:public_key_path).returns @public_key_path
      @searcher.stubs(:path).returns @private_key_path

      FileTest.stubs(:directory?).returns true
      FileTest.stubs(:writable?).returns true

      @public_key = stub 'public_key'
      @real_key = stub 'sslkey', :public_key => @public_key

      @key = stub 'key', :name => "myname", :content => @real_key

      @request = stub 'request', :key => "myname", :instance => @key
    end

    it "should save the public key when saving the private key" do
      fh = StringIO.new

      Oregano.settings.setting(:publickeydir).expects(:open_file).with(@public_key_path, 'w:ASCII').yields fh
      Oregano.settings.setting(:privatekeydir).stubs(:open_file)
      @public_key.expects(:to_pem).returns "my pem"

      @searcher.save(@request)

      expect(fh.string).to eq("my pem")
    end

    it "should destroy the public key when destroying the private key" do
      Oregano::FileSystem.expects(:unlink).with(Oregano::FileSystem.pathname(@private_key_path))
      Oregano::FileSystem.expects(:exist?).with(Oregano::FileSystem.pathname(@private_key_path)).returns true
      Oregano::FileSystem.expects(:exist?).with(Oregano::FileSystem.pathname(@public_key_path)).returns true
      Oregano::FileSystem.expects(:unlink).with(Oregano::FileSystem.pathname(@public_key_path))

      @searcher.destroy(@request)
    end

    it "should not fail if the public key does not exist when deleting the private key" do
      Oregano::FileSystem.stubs(:unlink).with(Oregano::FileSystem.pathname(@private_key_path))

      Oregano::FileSystem.stubs(:exist?).with(Oregano::FileSystem.pathname(@private_key_path)).returns true
      Oregano::FileSystem.expects(:exist?).with(Oregano::FileSystem.pathname(@public_key_path)).returns false
      Oregano::FileSystem.expects(:unlink).with(Oregano::FileSystem.pathname(@public_key_path)).never

      @searcher.destroy(@request)
    end
  end
end
