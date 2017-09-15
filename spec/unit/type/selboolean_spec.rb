#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:selboolean), "when validating attributes" do
  [:name, :persistent].each do |param|
    it "should have a #{param} parameter" do
      expect(Oregano::Type.type(:selboolean).attrtype(param)).to eq(:param)
    end
  end

  it "should have a value property" do
    expect(Oregano::Type.type(:selboolean).attrtype(:value)).to eq(:property)
  end
end

describe Oregano::Type.type(:selboolean), "when validating values" do
  before do
    @class = Oregano::Type.type(:selboolean)

    @provider_class = stub 'provider_class', :name => "fake", :suitable? => true, :supports_parameter? => true
    @class.stubs(:defaultprovider).returns(@provider_class)
    @class.stubs(:provider).returns(@provider_class)

    @provider = stub 'provider', :class => @provider_class, :clear => nil
    @provider_class.stubs(:new).returns(@provider)
  end

  it "should support :on as a value to :value" do
    Oregano::Type.type(:selboolean).new(:name => "yay", :value => :on)
  end

  it "should support :off as a value to :value" do
    Oregano::Type.type(:selboolean).new(:name => "yay", :value => :off)
  end

  it "should support :true as a value to :persistent" do
    Oregano::Type.type(:selboolean).new(:name => "yay", :value => :on, :persistent => :true)
  end

  it "should support :false as a value to :persistent" do
    Oregano::Type.type(:selboolean).new(:name => "yay", :value => :on, :persistent => :false)
  end
end

