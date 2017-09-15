#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:file).attrclass(:type) do
  require 'oregano_spec/files'
  include OreganoSpec::Files

  before do
    @filename = tmpfile('type')
    @resource = Oregano::Type.type(:file).new({:name => @filename})
  end

  it "should prevent the user from trying to set the type" do
    expect {
      @resource[:type] = "fifo"
    }.to raise_error(Oregano::Error, /type is read-only/)
  end

end
