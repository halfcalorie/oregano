#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/type/selboolean'
require 'oregano/type/selmodule'

describe Oregano::Type.type(:file), " when manipulating file contexts" do
  include OreganoSpec::Files

  before :each do

    @file = Oregano::Type::File.new(
      :name => make_absolute("/tmp/foo"),
      :ensure => "file",
      :seluser => "user_u",
      :selrole => "role_r",
      :seltype => "type_t")
  end

  it "should use :seluser to get/set an SELinux user file context attribute" do
    expect(@file[:seluser]).to eq("user_u")
  end

  it "should use :selrole to get/set an SELinux role file context attribute" do
    expect(@file[:selrole]).to eq("role_r")
  end

  it "should use :seltype to get/set an SELinux user file context attribute" do
    expect(@file[:seltype]).to eq("type_t")
  end
end

describe Oregano::Type.type(:selboolean), " when manipulating booleans" do
  before :each do
    provider_class = Oregano::Type::Selboolean.provider(Oregano::Type::Selboolean.providers[0])
    Oregano::Type::Selboolean.stubs(:defaultprovider).returns provider_class

    @bool = Oregano::Type::Selboolean.new(
      :name => "foo",
      :value => "on",
      :persistent => true )
  end

  it "should be able to access :name" do
    expect(@bool[:name]).to eq("foo")
  end

  it "should be able to access :value" do
    expect(@bool.property(:value).should).to eq(:on)
  end

  it "should set :value to off" do
    @bool[:value] = :off
    expect(@bool.property(:value).should).to eq(:off)
  end

  it "should be able to access :persistent" do
    expect(@bool[:persistent]).to eq(:true)
  end

  it "should set :persistent to false" do
    @bool[:persistent] = false
    expect(@bool[:persistent]).to eq(:false)
  end
end

describe Oregano::Type.type(:selmodule), " when checking policy modules" do
  before :each do
    provider_class = Oregano::Type::Selmodule.provider(Oregano::Type::Selmodule.providers[0])
    Oregano::Type::Selmodule.stubs(:defaultprovider).returns provider_class

    @module = Oregano::Type::Selmodule.new(
      :name => "foo",
      :selmoduledir => "/some/path",
      :selmodulepath => "/some/path/foo.pp",
      :syncversion => true)
  end

  it "should be able to access :name" do
    expect(@module[:name]).to eq("foo")
  end

  it "should be able to access :selmoduledir" do
    expect(@module[:selmoduledir]).to eq("/some/path")
  end

  it "should be able to access :selmodulepath" do
    expect(@module[:selmodulepath]).to eq("/some/path/foo.pp")
  end

  it "should be able to access :syncversion" do
    expect(@module[:syncversion]).to eq(:true)
  end

  it "should set the syncversion value to false" do
    @module[:syncversion] = :false
    expect(@module[:syncversion]).to eq(:false)
  end
end
