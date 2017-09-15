#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/host'

describe Oregano::SSL::Host do
  include OreganoSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("host_integration_testing")

    Oregano.settings[:confdir] = dir
    Oregano.settings[:vardir] = dir

    Oregano::SSL::Host.ca_location = :local

    @host = Oregano::SSL::Host.new("luke.madstop.com")
    @ca = Oregano::SSL::CertificateAuthority.new
  end

  after {
    Oregano::SSL::Host.ca_location = :none
  }

  it "should be considered a CA host if its name is equal to 'ca'" do
    expect(Oregano::SSL::Host.new(Oregano::SSL::CA_NAME)).to be_ca
  end

  describe "when managing its key" do
    it "should be able to generate and save a key" do
      @host.generate_key
    end

    it "should save the key such that the Indirector can find it" do
      @host.generate_key

      expect(Oregano::SSL::Key.indirection.find(@host.name).content.to_s).to eq(@host.key.to_s)
    end

    it "should save the private key into the :privatekeydir" do
      @host.generate_key
      expect(File.read(File.join(Oregano.settings[:privatekeydir], "luke.madstop.com.pem"))).to eq(@host.key.to_s)
    end
  end

  describe "when managing its certificate request" do
    it "should be able to generate and save a certificate request" do
      @host.generate_certificate_request
    end

    it "should save the certificate request such that the Indirector can find it" do
      @host.generate_certificate_request

      expect(Oregano::SSL::CertificateRequest.indirection.find(@host.name).content.to_s).to eq(@host.certificate_request.to_s)
    end

    it "should save the private certificate request into the :privatekeydir" do
      @host.generate_certificate_request
      expect(File.read(File.join(Oregano.settings[:requestdir], "luke.madstop.com.pem"))).to eq(@host.certificate_request.to_s)
    end
  end

  describe "when the CA host" do
    it "should never store its key in the :privatekeydir" do
      Oregano.settings.use(:main, :ssl, :ca)
      @ca = Oregano::SSL::Host.new(Oregano::SSL::Host.ca_name)
      @ca.generate_key

      expect(Oregano::FileSystem.exist?(File.join(Oregano[:privatekeydir], "ca.pem"))).to be_falsey
    end
  end

  it "should pass the verification of its own SSL store", :unless => Oregano.features.microsoft_windows? do
    @host.generate
    @ca = Oregano::SSL::CertificateAuthority.new
    @ca.sign(@host.name)

    expect(@host.ssl_store.verify(@host.certificate.content)).to be_truthy
  end
end
