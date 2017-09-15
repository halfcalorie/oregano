#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/resource'
require 'oregano/indirector/memory'
require 'oregano/indirector/resource/store_configs'

class Oregano::Resource::StoreConfigsTesting < Oregano::Indirector::Memory
end

describe Oregano::Resource::StoreConfigs do
  it_should_behave_like "a StoreConfigs terminus"

  before :each do
    Oregano[:storeconfigs] = true
    Oregano[:storeconfigs_backend] = "store_configs_testing"
  end

  it "disallows remote requests" do
    expect(Oregano::Resource::StoreConfigs.new.allow_remote_requests?).to eq(false)
  end
end
