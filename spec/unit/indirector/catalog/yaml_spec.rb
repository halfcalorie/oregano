#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/resource/catalog'
require 'oregano/indirector/catalog/yaml'

describe Oregano::Resource::Catalog::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Oregano::Resource::Catalog::Yaml.superclass).to equal(Oregano::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Oregano::Resource::Catalog::Yaml.doc).not_to be_nil
  end

  it "should be registered with the catalog store indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:catalog)
    expect(Oregano::Resource::Catalog::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :yaml" do
    expect(Oregano::Resource::Catalog::Yaml.name).to eq(:yaml)
  end
end
