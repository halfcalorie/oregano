#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_metadata/file_server'

describe Oregano::Indirector::FileMetadata::FileServer do
  it "should be registered with the file_metadata indirection" do
    expect(Oregano::Indirector::Terminus.terminus_class(:file_metadata, :file_server)).to equal(Oregano::Indirector::FileMetadata::FileServer)
  end

  it "should be a subclass of the FileServer terminus" do
    expect(Oregano::Indirector::FileMetadata::FileServer.superclass).to equal(Oregano::Indirector::FileServer)
  end
end
