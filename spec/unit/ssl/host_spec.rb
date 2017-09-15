#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/ssl/host'
require 'matchers/json'

def base_json_comparison(result, json_hash)
  expect(result["fingerprint"]).to eq(json_hash["fingerprint"])
  expect(result["name"]).to        eq(json_hash["name"])
  expect(result["state"]).to       eq(json_hash["desired_state"])
end

describe Oregano::SSL::Host do
  include JSONMatchers
  include OreganoSpec::Files

  before do
    Oregano::SSL::Host.indirection.terminus_class = :file

    # Get a safe temporary file
    dir = tmpdir("ssl_host_testing")
    Oregano.settings[:confdir] = dir
    Oregano.settings[:vardir] = dir
    Oregano.settings.use :main, :ssl

    @host = Oregano::SSL::Host.new("myname")
  end

  after do
    # Cleaned out any cached localhost instance.
    Oregano::SSL::Host.reset
    Oregano::SSL::Host.ca_location = :none
  end

  it "should use any provided name as its name" do
    expect(@host.name).to eq("myname")
  end

  it "should retrieve its public key from its private key" do
    realkey = mock 'realkey'
    key = stub 'key', :content => realkey
    Oregano::SSL::Key.indirection.stubs(:find).returns(key)
    pubkey = mock 'public_key'
    realkey.expects(:public_key).returns pubkey

    expect(@host.public_key).to equal(pubkey)
  end

  it "should default to being a non-ca host" do
    expect(@host.ca?).to be_falsey
  end

  it "should be a ca host if its name matches the CA_NAME" do
    Oregano::SSL::Host.stubs(:ca_name).returns "yayca"
    expect(Oregano::SSL::Host.new("yayca")).to be_ca
  end

  it "should have a method for determining the CA location" do
    expect(Oregano::SSL::Host).to respond_to(:ca_location)
  end

  it "should have a method for specifying the CA location" do
    expect(Oregano::SSL::Host).to respond_to(:ca_location=)
  end

  it "should have a method for retrieving the default ssl host" do
    expect(Oregano::SSL::Host).to respond_to(:ca_location=)
  end

  it "should have a method for producing an instance to manage the local host's keys" do
    expect(Oregano::SSL::Host).to respond_to(:localhost)
  end

  it "should allow to reset localhost" do
    previous_host = Oregano::SSL::Host.localhost
    Oregano::SSL::Host.reset
    expect(Oregano::SSL::Host.localhost).not_to eq(previous_host)
  end

  it "should generate the certificate for the localhost instance if no certificate is available" do
    host = stub 'host', :key => nil
    Oregano::SSL::Host.expects(:new).returns host

    host.expects(:certificate).returns nil
    host.expects(:generate)

    expect(Oregano::SSL::Host.localhost).to equal(host)
  end

  it "should create a localhost cert if no cert is available and it is a CA with autosign and it is using DNS alt names", :unless => Oregano.features.microsoft_windows? do
    Oregano[:autosign] = true
    Oregano[:confdir] = tmpdir('conf')
    Oregano[:dns_alt_names] = "foo,bar,baz"
    ca = Oregano::SSL::CertificateAuthority.new
    Oregano::SSL::CertificateAuthority.stubs(:instance).returns ca

    localhost = Oregano::SSL::Host.localhost
    cert = localhost.certificate

    expect(cert).to be_a(Oregano::SSL::Certificate)
    expect(cert.subject_alt_names).to match_array(%W[DNS:#{Oregano[:certname]} DNS:foo DNS:bar DNS:baz])
  end

  context "with dns_alt_names" do
    before :each do
      @key = stub('key content')
      key = stub('key', :generate => true, :content => @key)
      Oregano::SSL::Key.stubs(:new).returns key
      Oregano::SSL::Key.indirection.stubs(:save).with(key)

      @cr = stub('certificate request')
      Oregano::SSL::CertificateRequest.stubs(:new).returns @cr
      Oregano::SSL::CertificateRequest.indirection.stubs(:save).with(@cr)
    end

    describe "explicitly specified" do
      before :each do
        Oregano[:dns_alt_names] = 'one, two'
      end

      it "should not include subjectAltName if not the local node" do
        @cr.expects(:generate).with(@key, {})

        Oregano::SSL::Host.new('not-the-' + Oregano[:certname]).generate
      end

      it "should include subjectAltName if I am a CA" do
        @cr.expects(:generate).
          with(@key, { :dns_alt_names => Oregano[:dns_alt_names] })

        Oregano::SSL::Host.localhost
      end
    end

    describe "implicitly defaulted" do
      let(:ca) { stub('ca', :sign => nil) }

      before :each do
        Oregano[:dns_alt_names] = ''

        Oregano::SSL::CertificateAuthority.stubs(:instance).returns ca
      end

      it "should not include defaults if we're not the CA" do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns false

        @cr.expects(:generate).with(@key, {})

        Oregano::SSL::Host.localhost
      end

      it "should not include defaults if not the local node" do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns true

        @cr.expects(:generate).with(@key, {})

        Oregano::SSL::Host.new('not-the-' + Oregano[:certname]).generate
      end

      it "should not include defaults if we can't resolve our fqdn" do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns true
        Facter.stubs(:value).with(:fqdn).returns nil

        @cr.expects(:generate).with(@key, {})

        Oregano::SSL::Host.localhost
      end

      it "should provide defaults if we're bootstrapping the local master" do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns true
        Facter.stubs(:value).with(:fqdn).returns 'web.foo.com'
        Facter.stubs(:value).with(:domain).returns 'foo.com'

        @cr.expects(:generate).with(@key, {:dns_alt_names => "oregano, web.foo.com, oregano.foo.com"})

        Oregano::SSL::Host.localhost
      end
    end
  end

  it "should always read the key for the localhost instance in from disk" do
    host = stub 'host', :certificate => "eh"
    Oregano::SSL::Host.expects(:new).returns host

    host.expects(:key)

    Oregano::SSL::Host.localhost
  end

  it "should cache the localhost instance" do
    host = stub 'host', :certificate => "eh", :key => 'foo'
    Oregano::SSL::Host.expects(:new).once.returns host
    expect(Oregano::SSL::Host.localhost).to eq(Oregano::SSL::Host.localhost)
  end

  it "should be able to verify its certificate matches its key" do
    expect(Oregano::SSL::Host.new("foo")).to respond_to(:validate_certificate_with_key)
  end

  it "should consider the certificate invalid if it cannot find a key" do
    host = Oregano::SSL::Host.new("foo")
    certificate = mock('cert', :fingerprint => 'DEADBEEF')
    host.expects(:certificate).twice.returns certificate
    host.expects(:key).returns nil
    expect { host.validate_certificate_with_key }.to raise_error(Oregano::Error, "No private key with which to validate certificate with fingerprint: DEADBEEF")
  end

  it "should consider the certificate invalid if it cannot find a certificate" do
    host = Oregano::SSL::Host.new("foo")
    host.expects(:key).never
    host.expects(:certificate).returns nil
    expect { host.validate_certificate_with_key }.to raise_error(Oregano::Error, "No certificate to validate.")
  end

  it "should consider the certificate invalid if the SSL certificate's key verification fails" do
    host = Oregano::SSL::Host.new("foo")
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', {:content => sslcert, :fingerprint => 'DEADBEEF'}
    host.stubs(:key).returns key
    host.stubs(:certificate).returns certificate
    sslcert.expects(:check_private_key).with("private_key").returns false
    expect { host.validate_certificate_with_key }.to raise_error(Oregano::Error, /DEADBEEF/)
  end

  it "should consider the certificate valid if the SSL certificate's key verification succeeds" do
    host = Oregano::SSL::Host.new("foo")
    key = mock 'key', :content => "private_key"
    sslcert = mock 'sslcert'
    certificate = mock 'cert', :content => sslcert
    host.stubs(:key).returns key
    host.stubs(:certificate).returns certificate
    sslcert.expects(:check_private_key).with("private_key").returns true
    expect{ host.validate_certificate_with_key }.not_to raise_error
  end

  describe "when specifying the CA location" do
    it "should support the location ':local'" do
      expect { Oregano::SSL::Host.ca_location = :local }.not_to raise_error
    end

    it "should support the location ':remote'" do
      expect { Oregano::SSL::Host.ca_location = :remote }.not_to raise_error
    end

    it "should support the location ':none'" do
      expect { Oregano::SSL::Host.ca_location = :none }.not_to raise_error
    end

    it "should support the location ':only'" do
      expect { Oregano::SSL::Host.ca_location = :only }.not_to raise_error
    end

    it "should not support other modes" do
      expect { Oregano::SSL::Host.ca_location = :whatever }.to raise_error(ArgumentError)
    end

    describe "as 'local'" do
      before do
        Oregano::SSL::Host.ca_location = :local
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Oregano::SSL::Certificate.indirection.cache_class).to eq(:file)
        expect(Oregano::SSL::CertificateRequest.indirection.cache_class).to eq(:file)
        expect(Oregano::SSL::CertificateRevocationList.indirection.cache_class).to eq(:file)
      end

      it "should set the terminus class for Key and Host as :file" do
        expect(Oregano::SSL::Key.indirection.terminus_class).to eq(:file)
        expect(Oregano::SSL::Host.indirection.terminus_class).to eq(:file)
      end

      it "should set the terminus class for Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
        expect(Oregano::SSL::Certificate.indirection.terminus_class).to eq(:ca)
        expect(Oregano::SSL::CertificateRequest.indirection.terminus_class).to eq(:ca)
        expect(Oregano::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:ca)
      end
    end

    describe "as 'remote'" do
      before do
        Oregano::SSL::Host.ca_location = :remote
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Oregano::SSL::Certificate.indirection.cache_class).to eq(:file)
        expect(Oregano::SSL::CertificateRequest.indirection.cache_class).to eq(:file)
        expect(Oregano::SSL::CertificateRevocationList.indirection.cache_class).to eq(:file)
      end

      it "should set the terminus class for Key as :file" do
        expect(Oregano::SSL::Key.indirection.terminus_class).to eq(:file)
      end

      it "should set the terminus class for Host, Certificate, CertificateRevocationList, and CertificateRequest as :rest" do
        expect(Oregano::SSL::Host.indirection.terminus_class).to eq(:rest)
        expect(Oregano::SSL::Certificate.indirection.terminus_class).to eq(:rest)
        expect(Oregano::SSL::CertificateRequest.indirection.terminus_class).to eq(:rest)
        expect(Oregano::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:rest)
      end
    end

    describe "as 'only'" do
      before do
        Oregano::SSL::Host.ca_location = :only
      end

      it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :ca" do
        expect(Oregano::SSL::Key.indirection.terminus_class).to eq(:ca)
        expect(Oregano::SSL::Certificate.indirection.terminus_class).to eq(:ca)
        expect(Oregano::SSL::CertificateRequest.indirection.terminus_class).to eq(:ca)
        expect(Oregano::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:ca)
      end

      it "should set the cache class for Certificate, CertificateRevocationList, and CertificateRequest to nil" do
        expect(Oregano::SSL::Certificate.indirection.cache_class).to be_nil
        expect(Oregano::SSL::CertificateRequest.indirection.cache_class).to be_nil
        expect(Oregano::SSL::CertificateRevocationList.indirection.cache_class).to be_nil
      end

      it "should set the terminus class for Host to :file" do
        expect(Oregano::SSL::Host.indirection.terminus_class).to eq(:file)
      end
    end

    describe "as 'none'" do
      before do
        Oregano::SSL::Host.ca_location = :none
      end

      it "should set the terminus class for Key, Certificate, CertificateRevocationList, and CertificateRequest as :file" do
        expect(Oregano::SSL::Key.indirection.terminus_class).to eq(:disabled_ca)
        expect(Oregano::SSL::Certificate.indirection.terminus_class).to eq(:disabled_ca)
        expect(Oregano::SSL::CertificateRequest.indirection.terminus_class).to eq(:disabled_ca)
        expect(Oregano::SSL::CertificateRevocationList.indirection.terminus_class).to eq(:disabled_ca)
      end

      it "should set the terminus class for Host to 'none'" do
        expect { Oregano::SSL::Host.indirection.terminus_class }.to raise_error(Oregano::DevError)
      end
    end
  end

  it "should have a class method for destroying all files related to a given host" do
    expect(Oregano::SSL::Host).to respond_to(:destroy)
  end

  describe "when destroying a host's SSL files" do
    before do
      Oregano::SSL::Key.indirection.stubs(:destroy).returns false
      Oregano::SSL::Certificate.indirection.stubs(:destroy).returns false
      Oregano::SSL::CertificateRequest.indirection.stubs(:destroy).returns false
    end

    it "should destroy its certificate, certificate request, and key" do
      Oregano::SSL::Key.indirection.expects(:destroy).with("myhost")
      Oregano::SSL::Certificate.indirection.expects(:destroy).with("myhost")
      Oregano::SSL::CertificateRequest.indirection.expects(:destroy).with("myhost")

      Oregano::SSL::Host.destroy("myhost")
    end

    it "should return true if any of the classes returned true" do
      Oregano::SSL::Certificate.indirection.expects(:destroy).with("myhost").returns true

      expect(Oregano::SSL::Host.destroy("myhost")).to be_truthy
    end

    it "should report that nothing was deleted if none of the classes returned true" do
      expect(Oregano::SSL::Host.destroy("myhost")).to eq("Nothing was deleted")
    end
  end

  describe "when initializing" do
    it "should default its name to the :certname setting" do
      Oregano[:certname] = "myname"

      expect(Oregano::SSL::Host.new.name).to eq("myname")
    end

    it "should downcase a passed in name" do
      expect(Oregano::SSL::Host.new("Host.Domain.Com").name).to eq("host.domain.com")
    end

    it "should indicate that it is a CA host if its name matches the ca_name constant" do
      Oregano::SSL::Host.stubs(:ca_name).returns "myca"
      expect(Oregano::SSL::Host.new("myca")).to be_ca
    end
  end

  describe "when managing its private key" do
    before do
      @realkey = "mykey"
      @key = Oregano::SSL::Key.new("mykey")
      @key.content = @realkey
    end

    it "should return nil if the key is not set and cannot be found" do
      Oregano::SSL::Key.indirection.expects(:find).with("myname").returns(nil)
      expect(@host.key).to be_nil
    end

    it "should find the key in the Key class and return the Oregano instance" do
      Oregano::SSL::Key.indirection.expects(:find).with("myname").returns(@key)
      expect(@host.key).to equal(@key)
    end

    it "should be able to generate and save a new key" do
      Oregano::SSL::Key.expects(:new).with("myname").returns(@key)

      @key.expects(:generate)
      Oregano::SSL::Key.indirection.expects(:save)

      expect(@host.generate_key).to be_truthy
      expect(@host.key).to equal(@key)
    end

    it "should not retain keys that could not be saved" do
      Oregano::SSL::Key.expects(:new).with("myname").returns(@key)

      @key.stubs(:generate)
      Oregano::SSL::Key.indirection.expects(:save).raises "eh"

      expect { @host.generate_key }.to raise_error(RuntimeError)
      expect(@host.key).to be_nil
    end

    it "should return any previously found key without requerying" do
      Oregano::SSL::Key.indirection.expects(:find).with("myname").returns(@key).once
      expect(@host.key).to equal(@key)
      expect(@host.key).to equal(@key)
    end
  end

  describe "when managing its certificate request" do
    before do
      @realrequest = "real request"
      @request = Oregano::SSL::CertificateRequest.new("myname")
      @request.content = @realrequest
    end

    it "should return nil if the key is not set and cannot be found" do
      Oregano::SSL::CertificateRequest.indirection.expects(:find).with("myname").returns(nil)
      expect(@host.certificate_request).to be_nil
    end

    it "should find the request in the Key class and return it and return the Oregano SSL request" do
      Oregano::SSL::CertificateRequest.indirection.expects(:find).with("myname").returns @request

      expect(@host.certificate_request).to equal(@request)
    end

    it "should generate a new key when generating the cert request if no key exists" do
      Oregano::SSL::CertificateRequest.expects(:new).with("myname").returns @request

      key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"

      @host.expects(:key).times(2).returns(nil).then.returns(key)
      @host.expects(:generate_key).returns(key)

      @request.stubs(:generate)
      Oregano::SSL::CertificateRequest.indirection.stubs(:save)

      @host.generate_certificate_request
    end

    it "should be able to generate and save a new request using the private key" do
      Oregano::SSL::CertificateRequest.expects(:new).with("myname").returns @request

      key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"
      @host.stubs(:key).returns(key)
      @request.expects(:generate).with("mycontent", {})
      Oregano::SSL::CertificateRequest.indirection.expects(:save).with(@request)

      expect(@host.generate_certificate_request).to be_truthy
      expect(@host.certificate_request).to equal(@request)
    end

    it "should return any previously found request without requerying" do
      Oregano::SSL::CertificateRequest.indirection.expects(:find).with("myname").returns(@request).once

      expect(@host.certificate_request).to equal(@request)
      expect(@host.certificate_request).to equal(@request)
    end

    it "should not keep its certificate request in memory if the request cannot be saved" do
      Oregano::SSL::CertificateRequest.expects(:new).with("myname").returns @request

      key = stub 'key', :public_key => mock("public_key"), :content => "mycontent"
      @host.stubs(:key).returns(key)
      @request.stubs(:generate)
      @request.stubs(:name).returns("myname")
      terminus = stub 'terminus'
      terminus.stubs(:validate)
      Oregano::SSL::CertificateRequest.indirection.expects(:prepare).returns(terminus)
      terminus.expects(:save).with { |req| req.instance == @request && req.key == "myname" }.raises "eh"

      expect { @host.generate_certificate_request }.to raise_error(RuntimeError)

      expect(@host.instance_eval { @certificate_request }).to be_nil
    end
  end

  describe "when managing its certificate" do
    before do
      @realcert = mock 'certificate'
      @cert = stub 'cert', :content => @realcert
      @host.stubs(:key).returns mock("key")
      @host.stubs(:validate_certificate_with_key)
    end

    it "should find the CA certificate if it does not have a certificate" do
      Oregano::SSL::Certificate.indirection.expects(:find).with(Oregano::SSL::CA_NAME, :fail_on_404 => true).returns mock("cacert")
      Oregano::SSL::Certificate.indirection.stubs(:find).with("myname").returns @cert
      @host.certificate
    end

    it "should not find the CA certificate if it is the CA host" do
      @host.expects(:ca?).returns true
      Oregano::SSL::Certificate.indirection.stubs(:find)
      Oregano::SSL::Certificate.indirection.expects(:find).with(Oregano::SSL::CA_NAME, :fail_on_404 => true).never

      @host.certificate
    end

    it "should return nil if it cannot find a CA certificate" do
      Oregano::SSL::Certificate.indirection.expects(:find).with(Oregano::SSL::CA_NAME, :fail_on_404 => true).returns nil
      Oregano::SSL::Certificate.indirection.expects(:find).with("myname").never

      expect(@host.certificate).to be_nil
    end

    it "should find the key if it does not have one" do
      Oregano::SSL::Certificate.indirection.stubs(:find)
      @host.expects(:key).returns mock("key")
      @host.certificate
    end

    it "should generate the key if one cannot be found" do
      Oregano::SSL::Certificate.indirection.stubs(:find)
      @host.expects(:key).returns nil
      @host.expects(:generate_key)
      @host.certificate
    end

    it "should find the certificate in the Certificate class and return the Oregano certificate instance" do
      Oregano::SSL::Certificate.indirection.expects(:find).with(Oregano::SSL::CA_NAME, :fail_on_404 => true).returns mock("cacert")
      Oregano::SSL::Certificate.indirection.expects(:find).with("myname").returns @cert
      expect(@host.certificate).to equal(@cert)
    end

    it "should return any previously found certificate" do
      Oregano::SSL::Certificate.indirection.expects(:find).with(Oregano::SSL::CA_NAME, :fail_on_404 => true).returns mock("cacert")
      Oregano::SSL::Certificate.indirection.expects(:find).with("myname").returns(@cert).once

      expect(@host.certificate).to equal(@cert)
      expect(@host.certificate).to equal(@cert)
    end
  end

  it "should have a method for listing certificate hosts" do
    expect(Oregano::SSL::Host).to respond_to(:search)
  end

  describe "when listing certificate hosts" do
    it "should default to listing all clients with any file types" do
      Oregano::SSL::Key.indirection.expects(:search).returns []
      Oregano::SSL::Certificate.indirection.expects(:search).returns []
      Oregano::SSL::CertificateRequest.indirection.expects(:search).returns []
      Oregano::SSL::Host.search
    end

    it "should be able to list only clients with a key" do
      Oregano::SSL::Key.indirection.expects(:search).returns []
      Oregano::SSL::Certificate.indirection.expects(:search).never
      Oregano::SSL::CertificateRequest.indirection.expects(:search).never
      Oregano::SSL::Host.search :for => Oregano::SSL::Key
    end

    it "should be able to list only clients with a certificate" do
      Oregano::SSL::Key.indirection.expects(:search).never
      Oregano::SSL::Certificate.indirection.expects(:search).returns []
      Oregano::SSL::CertificateRequest.indirection.expects(:search).never
      Oregano::SSL::Host.search :for => Oregano::SSL::Certificate
    end

    it "should be able to list only clients with a certificate request" do
      Oregano::SSL::Key.indirection.expects(:search).never
      Oregano::SSL::Certificate.indirection.expects(:search).never
      Oregano::SSL::CertificateRequest.indirection.expects(:search).returns []
      Oregano::SSL::Host.search :for => Oregano::SSL::CertificateRequest
    end

    it "should return a Host instance created with the name of each found instance" do
      key  = stub 'key',  :name => "key",  :to_ary => nil
      cert = stub 'cert', :name => "cert", :to_ary => nil
      csr  = stub 'csr',  :name => "csr",  :to_ary => nil

      Oregano::SSL::Key.indirection.expects(:search).returns [key]
      Oregano::SSL::Certificate.indirection.expects(:search).returns [cert]
      Oregano::SSL::CertificateRequest.indirection.expects(:search).returns [csr]

      returned = []
      %w{key cert csr}.each do |name|
        result = mock(name)
        returned << result
        Oregano::SSL::Host.expects(:new).with(name).returns result
      end

      result = Oregano::SSL::Host.search
      returned.each do |r|
        expect(result).to be_include(r)
      end
    end
  end

  it "should have a method for generating all necessary files" do
    expect(Oregano::SSL::Host.new("me")).to respond_to(:generate)
  end

  describe "when generating files" do
    before do
      @host = Oregano::SSL::Host.new("me")
      @host.stubs(:generate_key)
      @host.stubs(:generate_certificate_request)
    end

    it "should generate a key if one is not present" do
      @host.stubs(:key).returns nil
      @host.expects(:generate_key)

      @host.generate
    end

    it "should generate a certificate request if one is not present" do
      @host.expects(:certificate_request).returns nil
      @host.expects(:generate_certificate_request)

      @host.generate
    end

    describe "and it can create a certificate authority" do
      before do
        @ca = mock 'ca'
        Oregano::SSL::CertificateAuthority.stubs(:instance).returns @ca
      end

      it "should use the CA to sign its certificate request if it does not have a certificate" do
        @host.expects(:certificate).returns nil

        @ca.expects(:sign).with(@host.name, {allow_dns_alt_names: true})

        @host.generate
      end
    end

    describe "and it cannot create a certificate authority" do
      before do
        Oregano::SSL::CertificateAuthority.stubs(:instance).returns nil
      end

      it "should seek its certificate" do
        @host.expects(:certificate)

        @host.generate
      end
    end
  end

  it "should have a method for creating an SSL store" do
    expect(Oregano::SSL::Host.new("me")).to respond_to(:ssl_store)
  end

  it "should always return the same store" do
    host = Oregano::SSL::Host.new("foo")
    store = mock 'store'
    store.stub_everything
    OpenSSL::X509::Store.expects(:new).returns store
    expect(host.ssl_store).to equal(host.ssl_store)
  end

  describe "when creating an SSL store" do
    before do
      @host = Oregano::SSL::Host.new("me")
      @store = mock 'store'
      @store.stub_everything
      OpenSSL::X509::Store.stubs(:new).returns @store

      Oregano[:localcacert] = "ssl_host_testing"

      Oregano::SSL::CertificateRevocationList.indirection.stubs(:find).returns(nil)
    end

    it "should accept a purpose" do
      @store.expects(:purpose=).with "my special purpose"
      @host.ssl_store("my special purpose")
    end

    it "should default to OpenSSL::X509::PURPOSE_ANY as the purpose" do
      @store.expects(:purpose=).with OpenSSL::X509::PURPOSE_ANY
      @host.ssl_store
    end

    it "should add the local CA cert file" do
      Oregano[:localcacert] = "/ca/cert/file"
      @store.expects(:add_file).with Oregano[:localcacert]
      @host.ssl_store
    end

    describe "and a CRL is available" do
      before do
        @crl = stub 'crl', :content => "real_crl"
        Oregano::SSL::CertificateRevocationList.indirection.stubs(:find).returns @crl
      end

      describe "and 'certificate_revocation' is true" do
        before do
          Oregano[:certificate_revocation] = true
        end

        it "should add the CRL" do
          @store.expects(:add_crl).with "real_crl"
          @host.ssl_store
        end

        it "should set the flags to OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK" do
          @store.expects(:flags=).with OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
          @host.ssl_store
        end
      end

      describe "and 'certificate_revocation' is false" do
        before do
          Oregano[:certificate_revocation] = false
        end

        it "should not add the CRL" do
          @store.expects(:add_crl).never
          @host.ssl_store
        end

        it "should not set the flags" do
          @store.expects(:flags=).never
          @host.ssl_store
        end
      end
    end
  end

  describe "when waiting for a cert" do
    before do
      @host = Oregano::SSL::Host.new("me")
    end

    it "should generate its certificate request and attempt to read the certificate again if no certificate is found" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate)
      @host.wait_for_cert(1)
    end

    it "should catch and log errors during CSR saving" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate).raises(RuntimeError).then.returns nil
      @host.stubs(:sleep)
      @host.wait_for_cert(1)
    end

    it "should sleep and retry after failures saving the CSR if waitforcert is enabled" do
      @host.expects(:certificate).times(2).returns(nil).then.returns "foo"
      @host.expects(:generate).raises(RuntimeError).then.returns nil
      @host.expects(:sleep).with(1)
      @host.wait_for_cert(1)
    end

    it "should exit after failures saving the CSR of waitforcert is disabled" do
      @host.expects(:certificate).returns(nil)
      @host.expects(:generate).raises(RuntimeError)
      @host.expects(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should exit if the wait time is 0 and it can neither find nor retrieve a certificate" do
      @host.stubs(:certificate).returns nil
      @host.expects(:generate)
      @host.expects(:puts)
      expect { @host.wait_for_cert(0) }.to exit_with 1
    end

    it "should sleep for the specified amount of time if no certificate is found after generating its certificate request" do
      @host.expects(:certificate).times(3).returns(nil).then.returns(nil).then.returns "foo"
      @host.expects(:generate)

      @host.expects(:sleep).with(1)

      @host.wait_for_cert(1)
    end

    it "should catch and log exceptions during certificate retrieval" do
      @host.expects(:certificate).times(3).returns(nil).then.raises(RuntimeError).then.returns("foo")
      @host.stubs(:generate)
      @host.stubs(:sleep)

      Oregano.expects(:err)

      @host.wait_for_cert(1)
    end
  end

  describe "when handling JSON", :unless => Oregano.features.microsoft_windows? do
    include OreganoSpec::Files

    before do
      Oregano[:vardir] = tmpdir("ssl_test_vardir")
      Oregano[:ssldir] = tmpdir("ssl_test_ssldir")
      # localcacert is where each client stores the CA certificate
      # cacert is where the master stores the CA certificate
      # Since we need to play the role of both for testing we need them to be the same and exist
      Oregano[:cacert] = Oregano[:localcacert]

      @ca=Oregano::SSL::CertificateAuthority.new
    end

    describe "when converting to JSON" do
      let(:host) do
        Oregano::SSL::Host.new("bazinga")
      end

      let(:json_hash) do
        {
          "fingerprint"   => host.certificate_request.fingerprint,
          "desired_state" => 'requested',
          "name"          => host.name
        }
      end

      it "should be able to identify a host with an unsigned certificate request" do
        host.generate_certificate_request

        result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)

        base_json_comparison result, json_hash
      end

      it "should validate against the schema" do
        host.generate_certificate_request

        expect(host.to_json).to validate_against('api/schemas/host.json')
      end

      describe "explicit fingerprints" do
        [:SHA1, :SHA256, :SHA512].each do |md|
          it "should include #{md}" do
            mds = md.to_s
            host.generate_certificate_request
            json_hash["fingerprints"] = {}
            json_hash["fingerprints"][mds] = host.certificate_request.fingerprint(md)

            result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)
            base_json_comparison result, json_hash
            expect(result["fingerprints"][mds]).to eq(json_hash["fingerprints"][mds])
          end
        end
      end

      describe "dns_alt_names" do
        describe "when not specified" do
          it "should include the dns_alt_names associated with the certificate" do
            host.generate_certificate_request
            json_hash["desired_alt_names"] = host.certificate_request.subject_alt_names

            result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)
            base_json_comparison result, json_hash
            expect(result["dns_alt_names"]).to eq(json_hash["desired_alt_names"])
          end
        end

        [ "",
          "test, alt, names"
        ].each do |alt_names|
          describe "when #{alt_names}" do
            before(:each) do
              host.generate_certificate_request :dns_alt_names => alt_names
            end

            it "should include the dns_alt_names associated with the certificate" do
              json_hash["desired_alt_names"] = host.certificate_request.subject_alt_names

              result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)
              base_json_comparison result, json_hash
              expect(result["dns_alt_names"]).to eq(json_hash["desired_alt_names"])
            end

            it "should validate against the schema" do
              expect(host.to_json).to validate_against('api/schemas/host.json')
            end
          end
        end
      end

      it "should be able to identify a host with a signed certificate" do
        host.generate_certificate_request
        @ca.sign(host.name)
        json_hash = {
          "fingerprint"          => Oregano::SSL::Certificate.indirection.find(host.name).fingerprint,
          "desired_state"        => 'signed',
          "name"                 => host.name,
        }

        result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)
        base_json_comparison result, json_hash
      end

      it "should be able to identify a host with a revoked certificate" do
        host.generate_certificate_request
        @ca.sign(host.name)
        @ca.revoke(host.name)
        json_hash["fingerprint"] = Oregano::SSL::Certificate.indirection.find(host.name).fingerprint
        json_hash["desired_state"] = 'revoked'

        result = JSON.parse(Oregano::SSL::Host.new(host.name).to_json)
        base_json_comparison result, json_hash
      end
    end

    describe "when converting from JSON" do
      it "should return a Oregano::SSL::Host object with the specified desired state" do
        host = Oregano::SSL::Host.new("bazinga")
        host.desired_state="signed"
        json_hash = {
          "name"  => host.name,
          "desired_state" => host.desired_state,
        }
        generated_host = Oregano::SSL::Host.from_data_hash(json_hash)
        expect(generated_host.desired_state).to eq(host.desired_state)
        expect(generated_host.name).to eq(host.name)
      end
    end
  end
end
