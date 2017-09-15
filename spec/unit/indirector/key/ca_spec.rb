#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/key/ca'

describe Oregano::SSL::Key::Ca do
  it "should have documentation" do
    expect(Oregano::SSL::Key::Ca.doc).to be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Oregano[:privatekeydir] = "/key/dir"
    expect(Oregano::SSL::Key::Ca.collection_directory).to eq(Oregano[:privatekeydir])
  end

  it "should store the ca key at the :cakey location" do
    Oregano.settings.stubs(:use)
    Oregano[:cakey] = "/ca/key"
    file = Oregano::SSL::Key::Ca.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Oregano[:cakey])
  end
end
