#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate_revocation_list/file'

describe Oregano::SSL::CertificateRevocationList::File do
  it "should have documentation" do
    expect(Oregano::SSL::CertificateRevocationList::File.doc).to be_instance_of(String)
  end

  it "should always store the file to :hostcrl location" do
    crl = File.expand_path("/host/crl")
    Oregano[:hostcrl] = crl
    Oregano.settings.stubs(:use)
    expect(Oregano::SSL::CertificateRevocationList::File.file_location).to eq(crl)
  end
end
