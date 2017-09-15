#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:stage) do
  it "should have a 'name' parameter'" do
    expect(Oregano::Type.type(:stage).new(:name => :foo)[:name]).to eq(:foo)
  end
end
