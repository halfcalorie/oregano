#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_content/file_server'

describe Oregano::Indirector::FileContent::FileServer do
  it "should be registered with the file_content indirection" do
    expect(Oregano::Indirector::Terminus.terminus_class(:file_content, :file_server)).to equal(Oregano::Indirector::FileContent::FileServer)
  end

  it "should be a subclass of the FileServer terminus" do
    expect(Oregano::Indirector::FileContent::FileServer.superclass).to equal(Oregano::Indirector::FileServer)
  end
end
