#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:ca, '0.1.0'] do
  it "should be deprecated" do
    expect(subject.deprecated?).to be_truthy
  end
end

