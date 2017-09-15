#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/reports'

describe Oregano::Reports, " when using report types" do
  before do
    Oregano.settings.stubs(:use)
  end

  it "should load report types as modules" do
    expect(Oregano::Reports.report(:store)).to be_instance_of(Module)
  end
end
