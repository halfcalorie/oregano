#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate_request/rest'

describe Oregano::SSL::CertificateRequest::Rest do
  before do
    @searcher = Oregano::SSL::CertificateRequest::Rest.new
  end

  it "should be a sublcass of Oregano::Indirector::REST" do
    expect(Oregano::SSL::CertificateRequest::Rest.superclass).to equal(Oregano::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    expect(Oregano::SSL::CertificateRequest::Rest.server_setting).to eq(:ca_server)
  end

  it "should set port_setting to :ca_port" do
    expect(Oregano::SSL::CertificateRequest::Rest.port_setting).to eq(:ca_port)
  end

  it "should use the :ca SRV service" do
    expect(Oregano::SSL::CertificateRequest::Rest.srv_service).to eq(:ca)
  end
end
