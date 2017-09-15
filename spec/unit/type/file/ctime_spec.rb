#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:file).attrclass(:ctime) do
  require 'oregano_spec/files'
  include OreganoSpec::Files

  before do
    @filename = tmpfile('ctime')
    @resource = Oregano::Type.type(:file).new({:name => @filename})
  end

  it "should be able to audit the file's ctime" do
    File.open(@filename, "w"){ }

    @resource[:audit] = [:ctime]

    # this .to_resource audit behavior is magical :-(
    expect(@resource.to_resource[:ctime]).to eq(Oregano::FileSystem.stat(@filename).ctime)
  end

  it "should return absent if auditing an absent file" do
    @resource[:audit] = [:ctime]

    expect(@resource.to_resource[:ctime]).to eq(:absent)
  end

  it "should prevent the user from trying to set the ctime" do
    expect {
      @resource[:ctime] = Time.now.to_s
    }.to raise_error(Oregano::Error, /ctime is read-only/)
  end

end
