#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/node'
require 'oregano/indirector/node/yaml'

describe Oregano::Node::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Oregano::Node::Yaml.superclass).to equal(Oregano::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Oregano::Node::Yaml.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:node)
    expect(Oregano::Node::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :node" do
    expect(Oregano::Node::Yaml.name).to eq(:yaml)
  end
end
