#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_metadata'
require 'oregano/indirector/file_metadata/rest'

describe "Oregano::Indirector::Metadata::Rest" do
  it "should add the node's cert name to the arguments"

  it "should use the :fileserver SRV service" do
    expect(Oregano::Indirector::FileMetadata::Rest.srv_service).to eq(:fileserver)
  end
end
