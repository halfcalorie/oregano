#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/catalog/rest'

describe Oregano::Resource::Catalog::Rest do
  it "should be a sublcass of Oregano::Indirector::REST" do
    expect(Oregano::Resource::Catalog::Rest.superclass).to equal(Oregano::Indirector::REST)
  end
end
