#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/node'
require 'oregano/indirector/node/msgpack'

describe Oregano::Node::Msgpack, :if => Oregano.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    expect(Oregano::Node::Msgpack.superclass).to equal(Oregano::Indirector::Msgpack)
  end

  it "should have documentation" do
    expect(Oregano::Node::Msgpack.doc).not_to be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:node)
    expect(Oregano::Node::Msgpack.indirection).to equal(indirection)
  end

  it "should have its name set to :msgpack" do
    expect(Oregano::Node::Msgpack.name).to eq(:msgpack)
  end
end
