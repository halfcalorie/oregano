#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/host'
require 'oregano/indirector/certificate_request/ca'

describe Oregano::SSL::CertificateRequest::Ca, :unless => Oregano.features.microsoft_windows? do
  include OreganoSpec::Files

  before :each do
    Oregano[:ssldir] = tmpdir('ssl')

    Oregano::SSL::Host.ca_location = :local
    Oregano[:localcacert] = Oregano[:cacert]

    @ca = Oregano::SSL::CertificateAuthority.new
  end

  after :all do
    Oregano::SSL::Host.ca_location = :none
  end

  it "should have documentation" do
    expect(Oregano::SSL::CertificateRequest::Ca.doc).to be_instance_of(String)
  end

  it "should use the :csrdir as the collection directory" do
    Oregano[:csrdir] = File.expand_path("/request/dir")
    expect(Oregano::SSL::CertificateRequest::Ca.collection_directory).to eq(Oregano[:csrdir])
  end

  it "should overwrite the previous certificate request if allow_duplicate_certs is true" do
    Oregano[:allow_duplicate_certs] = true
    host = Oregano::SSL::Host.new("foo")
    host.generate_certificate_request
    @ca.sign(host.name)

    Oregano::SSL::Host.indirection.find("foo").generate_certificate_request

    expect(Oregano::SSL::Certificate.indirection.find("foo").name).to eq("foo")
    expect(Oregano::SSL::CertificateRequest.indirection.find("foo").name).to eq("foo")
    expect(Oregano::SSL::Host.indirection.find("foo").state).to eq("requested")
  end

  it "should reject a new certificate request if allow_duplicate_certs is false" do
    Oregano[:allow_duplicate_certs] = false
    host = Oregano::SSL::Host.new("bar")
    host.generate_certificate_request
    @ca.sign(host.name)

    expect { Oregano::SSL::Host.indirection.find("bar").generate_certificate_request }.to raise_error(/ignoring certificate request/)

    expect(Oregano::SSL::Certificate.indirection.find("bar").name).to eq("bar")
    expect(Oregano::SSL::CertificateRequest.indirection.find("bar")).to be_nil
    expect(Oregano::SSL::Host.indirection.find("bar").state).to eq("signed")
  end
end
