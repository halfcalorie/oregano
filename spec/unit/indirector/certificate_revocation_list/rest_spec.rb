#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/certificate_revocation_list/rest'

describe Oregano::SSL::CertificateRevocationList::Rest do
  before do
    @searcher = Oregano::SSL::CertificateRevocationList::Rest.new
  end

  it "should be a sublcass of Oregano::Indirector::REST" do
    expect(Oregano::SSL::CertificateRevocationList::Rest.superclass).to equal(Oregano::Indirector::REST)
  end

  it "should set server_setting to :ca_server" do
    expect(Oregano::SSL::CertificateRevocationList::Rest.server_setting).to eq(:ca_server)
  end

  it "should set port_setting to :ca_port" do
    expect(Oregano::SSL::CertificateRevocationList::Rest.port_setting).to eq(:ca_port)
  end

  it "should use the :ca SRV service" do
    expect(Oregano::SSL::CertificateRevocationList::Rest.srv_service).to eq(:ca)
  end
end
