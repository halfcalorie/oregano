#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:vlan) do

  it "should have a 'name' parameter'" do
    expect(Oregano::Type.type(:vlan).new(:name => "200")[:name]).to eq("200")
  end

  it "should have a 'device_url' parameter'" do
    expect(Oregano::Type.type(:vlan).new(:name => "200", :device_url => :device)[:device_url]).to eq(:device)
  end

  it "should be applied on device" do
    expect(Oregano::Type.type(:vlan).new(:name => "200")).to be_appliable_to_device
  end

  it "should have an ensure property" do
    expect(Oregano::Type.type(:vlan).attrtype(:ensure)).to eq(:property)
  end

  it "should have a description property" do
    expect(Oregano::Type.type(:vlan).attrtype(:description)).to eq(:property)
  end

  describe "when validating attribute values" do
    before do
      @provider = stub 'provider', :class => Oregano::Type.type(:vlan).defaultprovider, :clear => nil
      Oregano::Type.type(:vlan).defaultprovider.stubs(:new).returns(@provider)
    end

    it "should support :present as a value to :ensure" do
      Oregano::Type.type(:vlan).new(:name => "200", :ensure => :present)
    end

    it "should support :absent as a value to :ensure" do
      Oregano::Type.type(:vlan).new(:name => "200", :ensure => :absent)
    end

    it "should fail if vlan name is not a number" do
      expect { Oregano::Type.type(:vlan).new(:name => "notanumber", :ensure => :present) }.to raise_error(Oregano::ResourceError, /Parameter name failed on Vlan/)
    end
  end
end
