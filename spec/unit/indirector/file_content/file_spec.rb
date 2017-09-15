#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_content/file'

describe Oregano::Indirector::FileContent::File do
  it "should be registered with the file_content indirection" do
    expect(Oregano::Indirector::Terminus.terminus_class(:file_content, :file)).to equal(Oregano::Indirector::FileContent::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    expect(Oregano::Indirector::FileContent::File.superclass).to equal(Oregano::Indirector::DirectFileServer)
  end
end
