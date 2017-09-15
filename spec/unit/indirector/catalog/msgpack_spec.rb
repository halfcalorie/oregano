#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/resource/catalog'
require 'oregano/indirector/catalog/msgpack'

describe Oregano::Resource::Catalog::Msgpack, :if => Oregano.features.msgpack? do
  # This is it for local functionality: we don't *do* anything else.
  it "should be registered with the catalog store indirection" do
    expect(Oregano::Resource::Catalog.indirection.terminus(:msgpack)).
      to be_an_instance_of described_class
  end
end
