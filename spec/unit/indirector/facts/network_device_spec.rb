#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/util/network_device'
require 'oregano/indirector/facts/network_device'

describe Oregano::Node::Facts::NetworkDevice do
  it "should be a subclass of the Code terminus" do
    expect(Oregano::Node::Facts::NetworkDevice.superclass).to equal(Oregano::Indirector::Code)
  end

  it "should have documentation" do
    expect(Oregano::Node::Facts::NetworkDevice.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:facts)
    expect(Oregano::Node::Facts::NetworkDevice.indirection).to equal(indirection)
  end

  it "should have its name set to :facter" do
    expect(Oregano::Node::Facts::NetworkDevice.name).to eq(:network_device)
  end
end

describe Oregano::Node::Facts::NetworkDevice do
  before :each do
    @remote_device = stub 'remote_device', :facts => {}
    Oregano::Util::NetworkDevice.stubs(:current).returns(@remote_device)
    @device = Oregano::Node::Facts::NetworkDevice.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe Oregano::Node::Facts::NetworkDevice, " when finding facts" do
    it "should return a Facts instance" do
      expect(@device.find(@request)).to be_instance_of(Oregano::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      expect(@device.find(@request).name).to eq(@name)
    end

    it "should return the device facts as the values in the Facts instance" do
      @remote_device.expects(:facts).returns("one" => "two")
      facts = @device.find(@request)
      expect(facts.values["one"]).to eq("two")
    end

    it "should add local facts" do
      facts = Oregano::Node::Facts.new("foo")
      Oregano::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      @device.find(@request)
    end

    it "should sanitize facts" do
      facts = Oregano::Node::Facts.new("foo")
      Oregano::Node::Facts.expects(:new).returns facts
      facts.expects(:sanitize)

      @device.find(@request)
    end
  end

  describe Oregano::Node::Facts::NetworkDevice, " when saving facts" do
    it "should fail" do
      expect { @device.save(@facts) }.to raise_error(Oregano::DevError)
    end
  end

  describe Oregano::Node::Facts::NetworkDevice, " when destroying facts" do
    it "should fail" do
      expect { @device.destroy(@facts) }.to raise_error(Oregano::DevError)
    end
  end
end
