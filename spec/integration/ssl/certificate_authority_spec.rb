#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/certificate_authority'

describe Oregano::SSL::CertificateAuthority, :unless => Oregano.features.microsoft_windows? do
  include OreganoSpec::Files

  let(:ca) { @ca }

  before do
    dir = tmpdir("ca_integration_testing")

    Oregano.settings[:confdir] = dir
    Oregano.settings[:vardir] = dir

    Oregano::SSL::Host.ca_location = :local

    # this has the side-effect of creating the various directories that we need
    @ca = Oregano::SSL::CertificateAuthority.new
  end

  it "should be able to generate a new host certificate" do
    ca.generate("newhost")

    expect(Oregano::SSL::Certificate.indirection.find("newhost")).to be_instance_of(Oregano::SSL::Certificate)
  end

  it "should be able to revoke a host certificate" do
    ca.generate("newhost")

    ca.revoke("newhost")

    expect { ca.verify("newhost") }.to raise_error(Oregano::SSL::CertificateAuthority::CertificateVerificationError, "certificate revoked")
  end

  describe "when signing certificates" do
    it "should save the signed certificate" do
      host = certificate_request_for("luke.madstop.com")

      ca.sign("luke.madstop.com")

      expect(Oregano::SSL::Certificate.indirection.find("luke.madstop.com")).to be_instance_of(Oregano::SSL::Certificate)
    end

    it "should be able to sign multiple certificates" do
      host = certificate_request_for("luke.madstop.com")
      other = certificate_request_for("other.madstop.com")

      ca.sign("luke.madstop.com")
      ca.sign("other.madstop.com")

      expect(Oregano::SSL::Certificate.indirection.find("other.madstop.com")).to be_instance_of(Oregano::SSL::Certificate)
      expect(Oregano::SSL::Certificate.indirection.find("luke.madstop.com")).to be_instance_of(Oregano::SSL::Certificate)
    end

    it "should save the signed certificate to the :signeddir" do
      host = certificate_request_for("luke.madstop.com")

      ca.sign("luke.madstop.com")

      client_cert = File.join(Oregano[:signeddir], "luke.madstop.com.pem")
      expect(File.read(client_cert)).to eq(Oregano::SSL::Certificate.indirection.find("luke.madstop.com").content.to_s)
    end

    it "should save valid certificates" do
      host = certificate_request_for("luke.madstop.com")

      ca.sign("luke.madstop.com")

      unless ssl = Oregano::Util::which('openssl')
        pending "No ssl available"
      else
        ca_cert = Oregano[:cacert]
        client_cert = File.join(Oregano[:signeddir], "luke.madstop.com.pem")
        output = %x{openssl verify -CAfile #{ca_cert} #{client_cert}}
        expect($CHILD_STATUS).to eq(0)
      end
    end

    it "should verify proof of possession when signing certificates" do
      host = certificate_request_for("luke.madstop.com")
      csr = host.certificate_request
      wrong_key = Oregano::SSL::Key.new(host.name)
      wrong_key.generate

      csr.content.public_key = wrong_key.content.public_key
      # The correct key has to be removed so we can save the incorrect one
      Oregano::SSL::CertificateRequest.indirection.destroy(host.name)
      Oregano::SSL::CertificateRequest.indirection.save(csr)

      expect {
        ca.sign(host.name)
      }.to raise_error(
        Oregano::SSL::CertificateAuthority::CertificateSigningError,
        "CSR contains a public key that does not correspond to the signing key"
      )
    end
  end

  describe "when revoking certificate" do
    it "should work for one certificate" do
      certificate_request_for("luke.madstop.com")

      ca.sign("luke.madstop.com")
      ca.revoke("luke.madstop.com")

      expect { ca.verify("luke.madstop.com") }.to raise_error(
        Oregano::SSL::CertificateAuthority::CertificateVerificationError,
        "certificate revoked"
      )
    end

    it "should work for several certificates" do
      3.times.each do |c|
        certificate_request_for("luke.madstop.com")
        ca.sign("luke.madstop.com")
        ca.destroy("luke.madstop.com")
      end
      ca.revoke("luke.madstop.com")

      expect(ca.crl.content.revoked.map { |r| r.serial }).to eq([2,3,4]) # ca has serial 1
    end

  end

  it "allows autosigning certificates concurrently", :unless => Oregano::Util::Platform.windows? do
    Oregano[:autosign] = true
    hosts = (0..4).collect { |i| certificate_request_for("host#{i}") }

    run_in_parallel(5) do |i|
      ca.autosign(Oregano::SSL::CertificateRequest.indirection.find(hosts[i].name))
    end

    certs = hosts.collect { |host| Oregano::SSL::Certificate.indirection.find(host.name).content }
    serial_numbers = certs.collect(&:serial)

    expect(serial_numbers.sort).to eq([2, 3, 4, 5, 6]) # serial 1 is the ca certificate
  end

  def certificate_request_for(hostname)
    key = Oregano::SSL::Key.new(hostname)
    key.generate

    host = Oregano::SSL::Host.new(hostname)
    host.key = key
    host.generate_certificate_request

    host
  end

  def run_in_parallel(number)
    children = []
    number.times do |i|
      children << Kernel.fork do
        yield i
      end
    end

    children.each { |pid| Process.wait(pid) }
  end
end
