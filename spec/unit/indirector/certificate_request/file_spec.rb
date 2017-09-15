#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate_request/file'

describe Oregano::SSL::CertificateRequest::File do
  it "should have documentation" do
    expect(Oregano::SSL::CertificateRequest::File.doc).to be_instance_of(String)
  end

  it "should use the :requestdir as the collection directory" do
    Oregano[:requestdir] = File.expand_path("/request/dir")
    expect(Oregano::SSL::CertificateRequest::File.collection_directory).to eq(Oregano[:requestdir])
  end
end
