#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/direct_file_server'

describe Oregano::Indirector::DirectFileServer do
  before :all do
    Oregano::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Oregano::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @direct_file_class = class Testing::Mytype < Oregano::Indirector::DirectFileServer
      self
    end

    @server = @direct_file_class.new

    @path = File.expand_path('/my/local')
    @uri = Oregano::Util.path_to_uri(@path).to_s

    @request = Oregano::Indirector::Request.new(:mytype, :find, @uri, nil)
  end

  describe Oregano::Indirector::DirectFileServer, "when finding a single file" do

    it "should return nil if the file does not exist" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns false
      expect(@server.find(@request)).to be_nil
    end

    it "should return a Content instance created with the full path to the file if the file exists" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns true
      mycontent = stub 'content', :collect => nil
      mycontent.expects(:collect)
      @model.expects(:new).returns(mycontent)
      expect(@server.find(@request)).to eq(mycontent)
    end
  end

  describe Oregano::Indirector::DirectFileServer, "when creating the instance for a single found file" do

    before do
      @data = mock 'content'
      @data.stubs(:collect)
      Oregano::FileSystem.expects(:exist?).with(@path).returns true
    end

    it "should pass the full path to the instance" do
      @model.expects(:new).with { |key, options| key == @path }.returns(@data)
      @server.find(@request)
    end

    it "should pass the :links setting on to the created Content instance if the file exists and there is a value for :links" do
      @model.expects(:new).returns(@data)
      @data.expects(:links=).with(:manage)

      @request.stubs(:options).returns(:links => :manage)
      @server.find(@request)
    end

    it "should set 'checksum_type' on the instances if it is set in the request options" do
      @model.expects(:new).returns(@data)
      @data.expects(:checksum_type=).with :checksum

      @request.stubs(:options).returns(:checksum_type => :checksum)
      @server.find(@request)
    end
  end

  describe Oregano::Indirector::DirectFileServer, "when searching for multiple files" do
    it "should return nil if the file does not exist" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns false
      expect(@server.find(@request)).to be_nil
    end

    it "should use :path2instances from the terminus_helper to return instances if the file exists" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns true
      @server.expects(:path2instances)
      @server.search(@request)
    end

    it "should pass the original request to :path2instances" do
      Oregano::FileSystem.expects(:exist?).with(@path).returns true
      @server.expects(:path2instances).with(@request, @path)
      @server.search(@request)
    end
  end
end
