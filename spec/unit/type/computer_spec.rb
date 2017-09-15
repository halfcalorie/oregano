#! /usr/bin/env ruby
require 'spec_helper'

computer = Oregano::Type.type(:computer)

describe Oregano::Type.type(:computer), " when checking computer objects" do
  before do
    provider_class = Oregano::Type::Computer.provider(Oregano::Type::Computer.providers[0])
    Oregano::Type::Computer.expects(:defaultprovider).returns provider_class

          @resource = Oregano::Type::Computer.new(
                
            :name => "oreganocomputertest",
            :en_address => "aa:bb:cc:dd:ee:ff",
        
            :ip_address => "1.2.3.4")
    @properties = {}
    @ensure = Oregano::Type::Computer.attrclass(:ensure).new(:resource => @resource)
  end

  it "should be able to create an instance" do
    provider_class = Oregano::Type::Computer.provider(Oregano::Type::Computer.providers[0])
    Oregano::Type::Computer.expects(:defaultprovider).returns provider_class
    expect(computer.new(:name => "bar")).not_to be_nil
  end

  properties = [:en_address, :ip_address]
  params = [:name]

  properties.each do |property|
    it "should have a #{property} property" do
      expect(computer.attrclass(property).ancestors).to be_include(Oregano::Property)
    end

    it "should have documentation for its #{property} property" do
      expect(computer.attrclass(property).doc).to be_instance_of(String)
    end

    it "should accept :absent as a value" do
      prop = computer.attrclass(property).new(:resource => @resource)
      prop.should = :absent
      expect(prop.should).to eq(:absent)
    end
  end

  params.each do |param|
    it "should have a #{param} parameter" do
      expect(computer.attrclass(param).ancestors).to be_include(Oregano::Parameter)
    end

    it "should have documentation for its #{param} parameter" do
      expect(computer.attrclass(param).doc).to be_instance_of(String)
    end
  end

  describe "default values" do
    before do
      provider_class = computer.provider(computer.providers[0])
      computer.expects(:defaultprovider).returns provider_class
    end

    it "should be nil for en_address" do
      expect(computer.new(:name => :en_address)[:en_address]).to eq(nil)
    end

    it "should be nil for ip_address" do
      expect(computer.new(:name => :ip_address)[:ip_address]).to eq(nil)
    end
  end

  describe "when managing the ensure property" do
    it "should support a :present value" do
      expect { @ensure.should = :present }.not_to raise_error
    end

    it "should support an :absent value" do
      expect { @ensure.should = :absent }.not_to raise_error
    end
  end
end
