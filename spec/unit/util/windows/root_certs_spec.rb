#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/util/windows'

describe "Oregano::Util::Windows::RootCerts", :if => Oregano::Util::Platform.windows? do
  let(:x509_store) { Oregano::Util::Windows::RootCerts.instance.to_a }

  it "should return at least one X509 certificate" do
    expect(x509_store.to_a.size).to be >= 1
  end

  it "should return an X509 certificate with a subject" do
    x509 = x509_store.first

    expect(x509.subject.to_s).to match(/CN=.*/)
  end
end
