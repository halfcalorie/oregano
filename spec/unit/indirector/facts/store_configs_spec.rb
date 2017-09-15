#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/node'
require 'oregano/indirector/memory'
require 'oregano/indirector/facts/store_configs'

class Oregano::Node::Facts::StoreConfigsTesting < Oregano::Indirector::Memory
end

describe Oregano::Node::Facts::StoreConfigs do
  after :all do
    Oregano::Node::Facts.indirection.reset_terminus_class
    Oregano::Node::Facts.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
