#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/ssl/host'
require 'oregano/indirector/certificate_status'

describe "Oregano::CertificateStatus::Rest" do
  before do
    @terminus = Oregano::SSL::Host.indirection.terminus(:rest)
  end

  it "should be a terminus on Oregano::SSL::Host" do
    expect(@terminus).to be_instance_of(Oregano::Indirector::CertificateStatus::Rest)
  end

  it "should use the :ca SRV service" do
    expect(Oregano::Indirector::CertificateStatus::Rest.srv_service).to eq(:ca)
  end
end
