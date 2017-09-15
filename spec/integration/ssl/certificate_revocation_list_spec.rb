#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/certificate_revocation_list'

describe Oregano::SSL::CertificateRevocationList do
  include OreganoSpec::Files

  before do
    # Get a safe temporary file
    dir = tmpdir("ca_integration_testing")

    Oregano.settings[:confdir] = dir
    Oregano.settings[:vardir] = dir

    Oregano::SSL::Host.ca_location = :local
  end

  after {
    Oregano::SSL::Host.ca_location = :none

    # This is necessary so the terminus instances don't lie around.
    Oregano::SSL::Host.indirection.termini.clear
  }

  it "should be able to read in written out CRLs with no revoked certificates" do
    ca = Oregano::SSL::CertificateAuthority.new

    raise "CRL not created" unless Oregano::FileSystem.exist?(Oregano[:hostcrl])

    crl = Oregano::SSL::CertificateRevocationList.new("crl_int_testing")
    crl.read(Oregano[:hostcrl])
  end
end
