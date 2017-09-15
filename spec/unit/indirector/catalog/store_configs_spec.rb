#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/node'
require 'oregano/indirector/memory'
require 'oregano/indirector/catalog/store_configs'

class Oregano::Resource::Catalog::StoreConfigsTesting < Oregano::Indirector::Memory
end

describe Oregano::Resource::Catalog::StoreConfigs do
  after :each do
    Oregano::Resource::Catalog.indirection.reset_terminus_class
    Oregano::Resource::Catalog.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
