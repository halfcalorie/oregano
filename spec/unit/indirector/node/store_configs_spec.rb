#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/node'
require 'oregano/indirector/memory'
require 'oregano/indirector/node/store_configs'

class Oregano::Node::StoreConfigsTesting < Oregano::Indirector::Memory
end

describe Oregano::Node::StoreConfigs do
  after :each do
    Oregano::Node.indirection.reset_terminus_class
    Oregano::Node.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
