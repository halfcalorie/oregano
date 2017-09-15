#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/property/ensure'

klass = Oregano::Property::Ensure

describe klass do
  it "should be a subclass of Property" do
    expect(klass.superclass).to eq(Oregano::Property)
  end
end
