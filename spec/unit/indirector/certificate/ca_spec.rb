#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate/ca'

describe Oregano::SSL::Certificate::Ca do
  it "should have documentation" do
    expect(Oregano::SSL::Certificate::Ca.doc).to be_instance_of(String)
  end

  it "should use the :signeddir as the collection directory" do
    Oregano[:signeddir] = File.expand_path("/cert/dir")
    expect(Oregano::SSL::Certificate::Ca.collection_directory).to eq(Oregano[:signeddir])
  end

  it "should store the ca certificate at the :cacert location" do
    Oregano.settings.stubs(:use)
    Oregano[:cacert] = File.expand_path("/ca/cert")
    file = Oregano::SSL::Certificate::Ca.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Oregano[:cacert])
  end
end
