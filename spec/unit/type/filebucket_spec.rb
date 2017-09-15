#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:filebucket) do
  include OreganoSpec::Files

  describe "when validating attributes" do
    %w{name server port path}.each do |attr|
      it "should have a '#{attr}' parameter" do
        expect(Oregano::Type.type(:filebucket).attrtype(attr.intern)).to eq(:param)
      end
    end

    it "should have its 'name' attribute set as its namevar" do
      expect(Oregano::Type.type(:filebucket).key_attributes).to eq([:name])
    end
  end

  it "should use the clientbucketdir as the path by default path" do
    Oregano.settings[:clientbucketdir] = "/my/bucket"
    expect(Oregano::Type.type(:filebucket).new(:name => "main")[:path]).to eq(Oregano[:clientbucketdir])
  end

  it "should use the masterport as the path by default port" do
    Oregano.settings[:masterport] = 50
    expect(Oregano::Type.type(:filebucket).new(:name => "main")[:port]).to eq(Oregano[:masterport])
  end

  it "should use the server as the path by default server" do
    Oregano.settings[:server] = "myserver"
    expect(Oregano::Type.type(:filebucket).new(:name => "main")[:server]).to eq(Oregano[:server])
  end

  it "be local by default" do
    bucket = Oregano::Type.type(:filebucket).new :name => "main"

    expect(bucket.bucket).to be_local
  end

  describe "path" do
    def bucket(hash)
      Oregano::Type.type(:filebucket).new({:name => 'main'}.merge(hash))
    end

    it "should accept false as a value" do
      expect { bucket(:path => false) }.not_to raise_error
    end

    it "should accept true as a value" do
      expect { bucket(:path => true) }.not_to raise_error
    end

    it "should fail when given an array of values" do
      expect { bucket(:path => ['one', 'two']) }.
        to raise_error Oregano::Error, /only have one filebucket path/
    end

    %w{one ../one one/two}.each do |path|
      it "should fail if given a relative path of #{path.inspect}" do
        expect { bucket(:path => path) }.
          to raise_error Oregano::Error, /Filebucket paths must be absolute/
      end
    end

    it "should succeed if given an absolute path" do
      expect { bucket(:path => make_absolute('/tmp/bucket')) }.not_to raise_error
    end

    it "not be local if path is false" do
      expect(bucket(:path => false).bucket).not_to be_local
    end

    it "be local if both a path and a server are specified" do
      expect(bucket(:server => "oregano", :path => make_absolute("/my/path")).bucket).to be_local
    end
  end

  describe "when creating the filebucket" do
    before do
      @bucket = stub 'bucket', :name= => nil
    end

    it "should use any provided path" do
      path = make_absolute("/foo/bar")
      bucket = Oregano::Type.type(:filebucket).new :name => "main", :path => path
      Oregano::FileBucket::Dipper.expects(:new).with(:Path => path).returns @bucket
      bucket.bucket
    end

    it "should use any provided server and port" do
      bucket = Oregano::Type.type(:filebucket).new :name => "main", :server => "myserv", :port => "myport", :path => false
      Oregano::FileBucket::Dipper.expects(:new).with(:Server => "myserv", :Port => "myport").returns @bucket
      bucket.bucket
    end

    it "should use the default server if the path is unset and no server is provided" do
      Oregano.settings[:server] = "myserv"
      bucket = Oregano::Type.type(:filebucket).new :name => "main", :path => false
      Oregano::FileBucket::Dipper.expects(:new).with { |args| args[:Server] == "myserv" }.returns @bucket
      bucket.bucket
    end
  end
end
