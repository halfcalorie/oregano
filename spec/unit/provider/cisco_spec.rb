#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/provider/cisco'

describe Oregano::Provider::Cisco do
  it "should implement a device class method" do
    expect(Oregano::Provider::Cisco).to respond_to(:device)
  end

  it "should create a cisco device instance" do
    Oregano::Util::NetworkDevice::Cisco::Device.expects(:new).returns :device
    expect(Oregano::Provider::Cisco.device(:url)).to eq(:device)
  end
end
