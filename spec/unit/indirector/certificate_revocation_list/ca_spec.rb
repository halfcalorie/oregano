#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate_revocation_list/ca'

describe Oregano::SSL::CertificateRevocationList::Ca do
  it "should have documentation" do
    expect(Oregano::SSL::CertificateRevocationList::Ca.doc).to be_instance_of(String)
  end

  it "should use the :cacrl setting as the crl location" do
    Oregano.settings.stubs(:use)
    Oregano[:cacrl] = File.expand_path("/request/dir")
    expect(Oregano::SSL::CertificateRevocationList::Ca.new.path("whatever")).to eq(Oregano[:cacrl])
  end
end
