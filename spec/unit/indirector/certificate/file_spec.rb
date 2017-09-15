#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate/file'

describe Oregano::SSL::Certificate::File do
  it "should have documentation" do
    expect(Oregano::SSL::Certificate::File.doc).to be_instance_of(String)
  end

  it "should use the :certdir as the collection directory" do
    Oregano[:certdir] = File.expand_path("/cert/dir")
    expect(Oregano::SSL::Certificate::File.collection_directory).to eq(Oregano[:certdir])
  end

  it "should store the ca certificate at the :localcacert location" do
    Oregano.settings.stubs(:use)
    Oregano[:localcacert] = File.expand_path("/ca/cert")
    file = Oregano::SSL::Certificate::File.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Oregano[:localcacert])
  end
end
