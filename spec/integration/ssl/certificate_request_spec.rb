#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/certificate_request'

describe Oregano::SSL::CertificateRequest do
  include OreganoSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("csr_integration_testing")

    Oregano.settings[:confdir] = dir
    Oregano.settings[:vardir] = dir

    Oregano::SSL::Host.ca_location = :none

    @csr = Oregano::SSL::CertificateRequest.new("luke.madstop.com")

    @key = OpenSSL::PKey::RSA.new(512)

    # This is necessary so the terminus instances don't lie around.
    Oregano::SSL::CertificateRequest.indirection.termini.clear
  end

  it "should be able to generate CSRs" do
    @csr.generate(@key)
  end

  it "should be able to save CSRs" do
    Oregano::SSL::CertificateRequest.indirection.save(@csr)
  end

  it "should be able to find saved certificate requests via the Indirector" do
    @csr.generate(@key)
    Oregano::SSL::CertificateRequest.indirection.save(@csr)

    expect(Oregano::SSL::CertificateRequest.indirection.find("luke.madstop.com")).to be_instance_of(Oregano::SSL::CertificateRequest)
  end

  it "should save the completely CSR when saving" do
    @csr.generate(@key)
    Oregano::SSL::CertificateRequest.indirection.save(@csr)

    expect(Oregano::SSL::CertificateRequest.indirection.find("luke.madstop.com").content.to_s).to eq(@csr.content.to_s)
  end
end
