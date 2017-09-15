#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_bucket_file/rest'

describe Oregano::FileBucketFile::Rest do
  it "should be a sublcass of Oregano::Indirector::REST" do
    expect(Oregano::FileBucketFile::Rest.superclass).to equal(Oregano::Indirector::REST)
  end
end
