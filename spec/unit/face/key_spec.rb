#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:key, '0.0.1'] do
  it "should be deprecated" do
    expect(subject.deprecated?).to be_truthy
  end
end

