#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/status/rest'

describe Oregano::Indirector::Status::Rest do
  it "should be a subclass of Oregano::Indirector::REST" do
    expect(Oregano::Indirector::Status::Rest.superclass).to equal(Oregano::Indirector::REST)
  end
end
