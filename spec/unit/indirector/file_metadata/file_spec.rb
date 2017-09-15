#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_metadata/file'

describe Oregano::Indirector::FileMetadata::File do
  it "should be registered with the file_metadata indirection" do
    expect(Oregano::Indirector::Terminus.terminus_class(:file_metadata, :file)).to equal(Oregano::Indirector::FileMetadata::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    expect(Oregano::Indirector::FileMetadata::File.superclass).to equal(Oregano::Indirector::DirectFileServer)
  end

  describe "when creating the instance for a single found file" do
    before do
      @metadata = Oregano::Indirector::FileMetadata::File.new
      @path = File.expand_path('/my/local')
      @uri = Oregano::Util.path_to_uri(@path).to_s
      @data = mock 'metadata'
      @data.stubs(:collect)
      Oregano::FileSystem.expects(:exist?).with(@path).returns true

      @request = Oregano::Indirector::Request.new(:file_metadata, :find, @uri, nil)
    end

    it "should collect its attributes when a file is found" do
      @data.expects(:collect)

      Oregano::FileServing::Metadata.expects(:new).returns(@data)
      expect(@metadata.find(@request)).to eq(@data)
    end
  end

  describe "when searching for multiple files" do
    before do
      @metadata = Oregano::Indirector::FileMetadata::File.new
      @path = File.expand_path('/my/local')
      @uri = Oregano::Util.path_to_uri(@path).to_s

      @request = Oregano::Indirector::Request.new(:file_metadata, :find, @uri, nil)
    end

    it "should collect the attributes of the instances returned" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns true
      Oregano::FileServing::Fileset.expects(:new).with(@path, @request).returns mock("fileset")
      Oregano::FileServing::Fileset.expects(:merge).returns [["one", @path], ["two", @path]]

      one = mock("one", :collect => nil)
      Oregano::FileServing::Metadata.expects(:new).with(@path, {:relative_path => "one"}).returns one

      two = mock("two", :collect => nil)
      Oregano::FileServing::Metadata.expects(:new).with(@path, {:relative_path => "two"}).returns two

      expect(@metadata.search(@request)).to eq([one, two])
    end
  end
end
