#! /usr/bin/env ruby
require 'spec_helper'

require 'ostruct'
require 'oregano/util/network_device'

describe Oregano::Util::NetworkDevice do

  before(:each) do
    @device = OpenStruct.new(:name => "name", :provider => "test", :url => "telnet://admin:password@127.0.0.1", :options => { :debug => false })
  end

  after(:each) do
    Oregano::Util::NetworkDevice.teardown
  end

  class Oregano::Util::NetworkDevice::Test
    class Device
      def initialize(device, options)
      end
    end
  end

  describe "when initializing the remote network device singleton" do
    it "should load the network device code" do
      Oregano::Util::NetworkDevice.expects(:require)
      Oregano::Util::NetworkDevice.init(@device)
    end

    it "should create a network device instance" do
      Oregano::Util::NetworkDevice.stubs(:require)
      Oregano::Util::NetworkDevice::Test::Device.expects(:new).with("telnet://admin:password@127.0.0.1", :debug => false)
      Oregano::Util::NetworkDevice.init(@device)
    end

    it "should raise an error if the remote device instance can't be created" do
      Oregano::Util::NetworkDevice.stubs(:require).raises("error")
      expect { Oregano::Util::NetworkDevice.init(@device) }.to raise_error(RuntimeError, /Can't load test for name/)
    end

    it "should let caller to access the singleton device" do
      device = stub 'device'
      Oregano::Util::NetworkDevice.stubs(:require)
      Oregano::Util::NetworkDevice::Test::Device.expects(:new).returns(device)
      Oregano::Util::NetworkDevice.init(@device)

      expect(Oregano::Util::NetworkDevice.current).to eq(device)
    end
  end
end
