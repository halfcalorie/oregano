#! /usr/bin/env ruby
# encoding: ASCII-8BIT
require 'spec_helper'

require 'oregano/ssl/certificate_authority'

describe Oregano::SSL::CertificateAuthority do
  after do
    Oregano::SSL::CertificateAuthority.instance_variable_set(:@singleton_instance, nil)
  end

  def stub_ca_host
    @key = mock 'key'
    @key.stubs(:content).returns "cakey"
    @cacert = mock 'certificate'
    @cacert.stubs(:content).returns "cacertificate"

    @host = stub 'ssl_host', :key => @key, :certificate => @cacert, :name => Oregano::SSL::Host.ca_name
  end

  it "should have a class method for returning a singleton instance" do
    expect(Oregano::SSL::CertificateAuthority).to respond_to(:instance)
  end

  describe "when finding an existing instance" do
    describe "and the host is a CA host and the run_mode is master" do
      before do
        Oregano[:ca] = true
        Oregano.run_mode.stubs(:master?).returns true

        @ca = mock('ca')
        Oregano::SSL::CertificateAuthority.stubs(:new).returns @ca
      end

      it "should return an instance" do
        expect(Oregano::SSL::CertificateAuthority.instance).to equal(@ca)
      end

      it "should always return the same instance" do
        expect(Oregano::SSL::CertificateAuthority.instance).to equal(Oregano::SSL::CertificateAuthority.instance)
      end
    end

    describe "and the host is not a CA host" do
      it "should return nil" do
        Oregano[:ca] = false
        Oregano.run_mode.stubs(:master?).returns true

        ca = mock('ca')
        Oregano::SSL::CertificateAuthority.expects(:new).never
        expect(Oregano::SSL::CertificateAuthority.instance).to be_nil
      end
    end

    describe "and the run_mode is not master" do
      it "should return nil" do
        Oregano[:ca] = true
        Oregano.run_mode.stubs(:master?).returns false

        ca = mock('ca')
        Oregano::SSL::CertificateAuthority.expects(:new).never
        expect(Oregano::SSL::CertificateAuthority.instance).to be_nil
      end
    end
  end

  describe "when initializing" do
    before do
      Oregano.settings.stubs(:use)

      Oregano::SSL::CertificateAuthority.any_instance.stubs(:setup)
    end

    it "should always set its name to the value of :certname" do
      Oregano[:certname] = "ca_testing"

      expect(Oregano::SSL::CertificateAuthority.new.name).to eq("ca_testing")
    end

    it "should create an SSL::Host instance whose name is the 'ca_name'" do
      Oregano::SSL::Host.expects(:ca_name).returns "caname"

      host = stub 'host'
      Oregano::SSL::Host.expects(:new).with("caname").returns host

      Oregano::SSL::CertificateAuthority.new
    end

    it "should use the :main, :ca, and :ssl settings sections" do
      Oregano.settings.expects(:use).with(:main, :ssl, :ca)
      Oregano::SSL::CertificateAuthority.new
    end

    it "should make sure the CA is set up" do
      Oregano::SSL::CertificateAuthority.any_instance.expects(:setup)

      Oregano::SSL::CertificateAuthority.new
    end
  end

  describe "when setting itself up" do
    it "should generate the CA certificate if it does not have one" do
      Oregano.settings.stubs :use

      host = stub 'host'
      Oregano::SSL::Host.stubs(:new).returns host

      host.expects(:certificate).returns nil

      Oregano::SSL::CertificateAuthority.any_instance.expects(:generate_ca_certificate)
      Oregano::SSL::CertificateAuthority.new
    end
  end

  describe "when retrieving the certificate revocation list" do
    before do
      Oregano.settings.stubs(:use)
      Oregano[:cacrl] = "/my/crl"

      cert = stub("certificate", :content => "real_cert")
      key = stub("key", :content => "real_key")
      @host = stub 'host', :certificate => cert, :name => "hostname", :key => key

      Oregano::SSL::CertificateAuthority.any_instance.stubs(:setup)
      @ca = Oregano::SSL::CertificateAuthority.new

      @ca.stubs(:host).returns @host
    end

    it "should return any found CRL instance" do
      crl = mock 'crl'
      Oregano::SSL::CertificateRevocationList.indirection.expects(:find).returns crl
      expect(@ca.crl).to equal(crl)
    end

    it "should create, generate, and save a new CRL instance of no CRL can be found" do
      crl = Oregano::SSL::CertificateRevocationList.new("fakename")
      Oregano::SSL::CertificateRevocationList.indirection.expects(:find).returns nil

      Oregano::SSL::CertificateRevocationList.expects(:new).returns crl

      crl.expects(:generate).with(@ca.host.certificate.content, @ca.host.key.content)
      Oregano::SSL::CertificateRevocationList.indirection.expects(:save).with(crl)

      expect(@ca.crl).to equal(crl)
    end
  end

  describe "when generating a self-signed CA certificate" do
    before do
      Oregano.settings.stubs(:use)

      Oregano::SSL::CertificateAuthority.any_instance.stubs(:setup)
      Oregano::SSL::CertificateAuthority.any_instance.stubs(:crl)
      @ca = Oregano::SSL::CertificateAuthority.new

      @host = stub 'host', :key => mock("key"), :name => "hostname", :certificate => mock('certificate')

      Oregano::SSL::CertificateRequest.any_instance.stubs(:generate)

      @ca.stubs(:host).returns @host
    end

    it "should create and store a password at :capass" do
      Oregano[:capass] = File.expand_path("/path/to/pass")

      Oregano::FileSystem.expects(:exist?).with(Oregano[:capass]).returns false

      fh = StringIO.new
      Oregano.settings.setting(:capass).expects(:open).with('w:ASCII').yields fh

      @ca.stubs(:sign)

      @ca.generate_ca_certificate

      expect(fh.string.length).to be > 18
    end

    it "should generate a key if one does not exist" do
      @ca.stubs :generate_password
      @ca.stubs :sign

      @ca.host.expects(:key).returns nil
      @ca.host.expects(:generate_key)

      @ca.generate_ca_certificate
    end

    it "should create and sign a self-signed cert using the CA name" do
      request = mock 'request'
      Oregano::SSL::CertificateRequest.expects(:new).with(@ca.host.name).returns request
      request.expects(:generate).with(@ca.host.key)
      request.stubs(:request_extensions => [])

      @ca.expects(:sign).with(@host.name, {allow_dns_alt_names: false,
                                           self_signing_csr: request})

      @ca.stubs :generate_password

      @ca.generate_ca_certificate
    end

    it "should generate its CRL" do
      @ca.stubs :generate_password
      @ca.stubs :sign

      @ca.host.expects(:key).returns nil
      @ca.host.expects(:generate_key)

      @ca.expects(:crl)

      @ca.generate_ca_certificate
    end
  end

  describe "when signing" do
    before do
      Oregano.settings.stubs(:use)

      Oregano::SSL::CertificateAuthority.any_instance.stubs(:password?).returns true

      stub_ca_host

      Oregano::SSL::Host.expects(:new).with(Oregano::SSL::Host.ca_name).returns @host

      @ca = Oregano::SSL::CertificateAuthority.new

      @name = "myhost"
      @real_cert = stub 'realcert', :sign => nil
      @cert = Oregano::SSL::Certificate.new(@name)
      @cert.content = @real_cert

      Oregano::SSL::Certificate.stubs(:new).returns @cert

      Oregano::SSL::Certificate.indirection.stubs(:save)

      # Stub out the factory
      Oregano::SSL::CertificateFactory.stubs(:build).returns @cert.content

      @request_content = stub "request content stub", :subject => OpenSSL::X509::Name.new([['CN', @name]]), :public_key => stub('public_key')
      @request = stub 'request', :name => @name, :request_extensions => [], :subject_alt_names => [], :content => @request_content
      @request_content.stubs(:verify).returns(true)

      # And the inventory
      @inventory = stub 'inventory', :add => nil
      @ca.stubs(:inventory).returns @inventory

      Oregano::SSL::CertificateRequest.indirection.stubs(:destroy)
    end

    describe "its own certificate" do
      before do
        @serial = 10
        @ca.stubs(:next_serial).returns @serial
      end

      it "should not look up a certificate request for the host" do
        Oregano::SSL::CertificateRequest.indirection.expects(:find).never

        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should use a certificate type of :ca" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          expect(args[0]).to eq(:ca)
        end.returns @cert.content
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should pass the provided CSR as the CSR" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          expect(args[1]).to eq(@request)
        end.returns @cert.content
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should use the provided CSR's content as the issuer" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          expect(args[2].subject.to_s).to eq("/CN=myhost")
        end.returns @cert.content
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should pass the next serial as the serial number" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          expect(args[3]).to eq(@serial)
        end.returns @cert.content
        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end

      it "should sign the certificate request even if it contains alt names" do
        @request.stubs(:subject_alt_names).returns %w[DNS:foo DNS:bar DNS:baz]

        expect do
          @ca.sign(@name, {allow_dns_alt_names: false,
                           self_signing_csr: @request})
        end.not_to raise_error
      end

      it "should save the resulting certificate" do
        Oregano::SSL::Certificate.indirection.expects(:save).with(@cert)

        @ca.sign(@name, {allow_dns_alt_names: true,
                         self_signing_csr: @request})
      end
    end

    describe "another host's certificate" do
      before do
        @serial = 10
        @ca.stubs(:next_serial).returns @serial

        Oregano::SSL::CertificateRequest.indirection.stubs(:find).with(@name).returns @request
        Oregano::SSL::CertificateRequest.indirection.stubs :save
      end

      it "should use a certificate type of :server" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          args[0] == :server
        end.returns @cert.content

        @ca.sign(@name)
      end

      it "should use look up a CSR for the host in the :ca_file terminus" do
        Oregano::SSL::CertificateRequest.indirection.expects(:find).with(@name).returns @request

        @ca.sign(@name)
      end

      it "should fail if no CSR can be found for the host" do
        Oregano::SSL::CertificateRequest.indirection.expects(:find).with(@name).returns nil

        expect { @ca.sign(@name) }.to raise_error(ArgumentError)
      end

      it "should fail if an unknown request extension is present" do
        @request.stubs :request_extensions => [{ "oid"   => "bananas",
                                                 "value" => "delicious" }]
        expect {
          @ca.sign(@name)
        }.to raise_error(/CSR has request extensions that are not permitted/)
      end

      it "should reject auth extensions" do
        @request.stubs :request_extensions => [{"oid" => "1.3.6.1.4.1.34380.1.3.1",
                                                "value" => "true"},
                                               {"oid" => "1.3.6.1.4.1.34380.1.3.13",
                                                "value" => "com"}]

        expect {
          @ca.sign(@name)
        }.to raise_error(Oregano::SSL::CertificateAuthority::CertificateSigningError,
                         /CSR '#{@name}' contains authorization extensions (.*?, .*?).*/)
      end

      it "should not fail if the CSR contains auth extensions and they're allowed" do
        @request.stubs :request_extensions => [{"oid" => "1.3.6.1.4.1.34380.1.3.1",
                                                "value" => "true"},
                                               {"oid" => "1.3.6.1.4.1.34380.1.3.13",
                                                "value" => "com"}]
        expect { @ca.sign(@name, {allow_authorization_extensions: true})}.to_not raise_error
      end

      it "should fail if the CSR contains alt names and they are not expected" do
        @request.stubs(:subject_alt_names).returns %w[DNS:foo DNS:bar DNS:baz]

        expect do
          @ca.sign(@name, {allow_dns_alt_names: false})
        end.to raise_error(Oregano::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{@name}' contains subject alternative names \(.*?\), which are disallowed. Use `oregano cert --allow-dns-alt-names sign #{@name}` to sign this request./)
      end

      it "should not fail if the CSR does not contain alt names and they are expected" do
        @request.stubs(:subject_alt_names).returns []
        expect { @ca.sign(@name, {allow_dns_alt_names: true}) }.to_not raise_error
      end

      it "should reject alt names by default" do
        @request.stubs(:subject_alt_names).returns %w[DNS:foo DNS:bar DNS:baz]

        expect do
          @ca.sign(@name)
        end.to raise_error(Oregano::SSL::CertificateAuthority::CertificateSigningError, /CSR '#{@name}' contains subject alternative names \(.*?\), which are disallowed. Use `oregano cert --allow-dns-alt-names sign #{@name}` to sign this request./)
      end

      it "should use the CA certificate as the issuer" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          args[2] == @cacert.content
        end.returns @cert.content
        signed = @ca.sign(@name)
      end

      it "should pass the next serial as the serial number" do
        Oregano::SSL::CertificateFactory.expects(:build).with do |*args|
          args[3] == @serial
        end.returns @cert.content
        @ca.sign(@name)
      end

      it "should sign the resulting certificate using its real key and a digest" do
        digest = mock 'digest'
        OpenSSL::Digest::SHA256.expects(:new).returns digest

        key = stub 'key', :content => "real_key"
        @ca.host.stubs(:key).returns key

        @cert.content.expects(:sign).with("real_key", digest)
        @ca.sign(@name)
      end

      it "should save the resulting certificate" do
        Oregano::SSL::Certificate.indirection.stubs(:save).with(@cert)
        @ca.sign(@name)
      end

      it "should remove the host's certificate request" do
        Oregano::SSL::CertificateRequest.indirection.expects(:destroy).with(@name)

        @ca.sign(@name)
      end

      it "should check the internal signing policies" do
        @ca.expects(:check_internal_signing_policies).returns true
        @ca.sign(@name)
      end
    end

    context "#check_internal_signing_policies" do
      before do
        @serial = 10
        @ca.stubs(:next_serial).returns @serial

        Oregano::SSL::CertificateRequest.indirection.stubs(:find).with(@name).returns @request
        @cert.stubs :save
      end

      it "should reject CSRs whose CN doesn't match the name for which we're signing them" do
        # Shorten this so the test doesn't take too long
        Oregano[:keylength] = 1024
        key = Oregano::SSL::Key.new('the_certname')
        key.generate

        csr = Oregano::SSL::CertificateRequest.new('the_certname')
        csr.generate(key)

        expect do
          @ca.check_internal_signing_policies('not_the_certname', csr)
        end.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /common name "the_certname" does not match expected certname "not_the_certname"/
        )
      end

      describe "when validating the CN" do
        before :all do
          Oregano[:keylength] = 1024
          Oregano[:passfile] = '/f00'
          @signing_key = Oregano::SSL::Key.new('my_signing_key')
          @signing_key.generate
        end

        [
         'completely_okay',
         'sure, why not? :)',
         'so+many(things)-are=allowed.',
         'this"is#just&madness%you[see]',
         'and even a (an?) \\!',
         'waltz, nymph, for quick jigs vex bud.',
         '{552c04ca-bb1b-11e1-874b-60334b04494e}'
        ].each do |name|
          it "should accept #{name.inspect}" do
            csr = Oregano::SSL::CertificateRequest.new(name)
            csr.generate(@signing_key)

            @ca.check_internal_signing_policies(name, csr)
          end
        end

        [
         'super/bad',
         "not\neven\tkind\rof",
         "ding\adong\a",
         "hidden\b\b\b\b\b\bmessage",
         "\xE2\x98\x83 :("
        ].each do |name|
          it "should reject #{name.inspect}" do
            # We aren't even allowed to make objects with these names, so let's
            # stub that to simulate an invalid one coming from outside Oregano
            Oregano::SSL::CertificateRequest.stubs(:validate_certname)
            csr = Oregano::SSL::CertificateRequest.new(name)
            csr.generate(@signing_key)

            expect do
              @ca.check_internal_signing_policies(name, csr)
            end.to raise_error(
              Oregano::SSL::CertificateAuthority::CertificateSigningError,
              /subject contains unprintable or non-ASCII characters/
            )
          end
        end
      end

      it "accepts numeric OIDs under the ppRegCertExt subtree" do
        exts = [{ 'oid' => '1.3.6.1.4.1.34380.1.1.1',
                  'value' => '657e4780-4cf5-11e3-8f96-0800200c9a66'}]

        @request.stubs(:request_extensions).returns exts

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end

      it "accepts short name OIDs under the ppRegCertExt subtree" do
        exts = [{ 'oid' => 'pp_uuid',
                  'value' => '657e4780-4cf5-11e3-8f96-0800200c9a66'}]

        @request.stubs(:request_extensions).returns exts

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end

      it "accepts OIDs under the ppPrivCertAttrs subtree" do
        exts = [{ 'oid' => '1.3.6.1.4.1.34380.1.2.1',
                  'value' => 'private extension'}]

        @request.stubs(:request_extensions).returns exts

        expect {
          @ca.check_internal_signing_policies(@name, @request)
        }.to_not raise_error
      end


      it "should reject a critical extension that isn't on the whitelist" do
        @request.stubs(:request_extensions).returns [{ "oid" => "banana",
                                                       "value" => "yumm",
                                                       "critical" => true }]
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject a non-critical extension that isn't on the whitelist" do
        @request.stubs(:request_extensions).returns [{ "oid" => "peach",
                                                       "value" => "meh",
                                                       "critical" => false }]
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject non-whitelist extensions even if a valid extension is present" do
        @request.stubs(:request_extensions).returns [{ "oid" => "peach",
                                                       "value" => "meh",
                                                       "critical" => false },
                                                     { "oid" => "subjectAltName",
                                                       "value" => "DNS:foo",
                                                       "critical" => true }]
        expect { @ca.check_internal_signing_policies(@name, @request) }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /request extensions that are not permitted/
        )
      end

      it "should reject a subjectAltName for a non-DNS value" do
        @request.stubs(:subject_alt_names).returns ['DNS:foo', 'email:bar@example.com']
        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: true})
        }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /subjectAltName outside the DNS label space/
        )
      end

      it "should allow a subjectAltName if subject matches CA's certname" do
        @request.stubs(:subject_alt_names).returns ['DNS:foo']
        Oregano[:certname] = @name

        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: false})
        }.to_not raise_error
      end

      it "should reject a wildcard subject" do
        @request.content.stubs(:subject).
          returns(OpenSSL::X509::Name.new([["CN", "*.local"]]))

        expect { @ca.check_internal_signing_policies('*.local', @request) }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /subject contains a wildcard/
        )
      end

      it "should reject a wildcard subjectAltName" do
        @request.stubs(:subject_alt_names).returns ['DNS:foo', 'DNS:*.bar']
        expect {
          @ca.check_internal_signing_policies(@name, @request, {allow_dns_alt_names: true})
        }.to raise_error(
          Oregano::SSL::CertificateAuthority::CertificateSigningError,
          /subjectAltName contains a wildcard/
        )
      end
    end

    it "should create a certificate instance with the content set to the newly signed x509 certificate" do
      @serial = 10
      @ca.stubs(:next_serial).returns @serial

      Oregano::SSL::CertificateRequest.indirection.stubs(:find).with(@name).returns @request
      Oregano::SSL::Certificate.indirection.stubs :save
      Oregano::SSL::Certificate.expects(:new).with(@name).returns @cert

      @ca.sign(@name)
    end

    it "should return the certificate instance" do
      @ca.stubs(:next_serial).returns @serial
      Oregano::SSL::CertificateRequest.indirection.stubs(:find).with(@name).returns @request
      Oregano::SSL::Certificate.indirection.stubs :save
      expect(@ca.sign(@name)).to equal(@cert)
    end

    it "should add the certificate to its inventory" do
      @ca.stubs(:next_serial).returns @serial
      @inventory.expects(:add).with(@cert)

      Oregano::SSL::CertificateRequest.indirection.stubs(:find).with(@name).returns @request
      Oregano::SSL::Certificate.indirection.stubs :save
      @ca.sign(@name)
    end

    it "should have a method for triggering autosigning of available CSRs" do
      expect(@ca).to respond_to(:autosign)
    end

    describe "when autosigning certificates" do
      let(:csr) { Oregano::SSL::CertificateRequest.new("host") }

      describe "using the autosign setting" do
        let(:autosign) { File.expand_path("/auto/sign") }

        it "should do nothing if autosign is disabled" do
          Oregano[:autosign] = false

          @ca.expects(:sign).never
          @ca.autosign(csr)
        end

        it "should do nothing if no autosign.conf exists" do
          Oregano[:autosign] = autosign
          non_existent_file = Oregano::FileSystem::MemoryFile.a_missing_file(autosign)
          Oregano::FileSystem.overlay(non_existent_file) do
            @ca.expects(:sign).never
            @ca.autosign(csr)
          end
        end

        describe "and autosign is enabled and the autosign.conf file exists" do
          let(:store) { stub 'store', :allow => nil, :allowed? => false }

          before do
            Oregano[:autosign] = autosign
          end

          describe "when creating the AuthStore instance to verify autosigning" do
            it "should create an AuthStore with each line in the configuration file allowed to be autosigned" do
              Oregano::FileSystem.overlay(Oregano::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\ntwo\n")) do
                Oregano::Network::AuthStore.stubs(:new).returns store

                store.expects(:allow).with("one")
                store.expects(:allow).with("two")

                @ca.autosign(csr)
              end
            end

            it "should reparse the autosign configuration on each call" do
              Oregano::FileSystem.overlay(Oregano::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one")) do
                Oregano::Network::AuthStore.stubs(:new).times(2).returns store

                @ca.autosign(csr)
                @ca.autosign(csr)
              end
            end

            it "should ignore comments" do
              Oregano::FileSystem.overlay(Oregano::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\n#two\n")) do
                Oregano::Network::AuthStore.stubs(:new).returns store

                store.expects(:allow).with("one")

                @ca.autosign(csr)
              end
            end

            it "should ignore blank lines" do
              Oregano::FileSystem.overlay(Oregano::FileSystem::MemoryFile.a_regular_file_containing(autosign, "one\n\n")) do
                Oregano::Network::AuthStore.stubs(:new).returns store

                store.expects(:allow).with("one")
                @ca.autosign(csr)
              end
            end
          end
        end
      end

      describe "using the autosign command setting" do
        let(:cmd) { File.expand_path('/autosign_cmd') }
        let(:autosign_cmd) { mock 'autosign_command' }
        let(:autosign_executable) { Oregano::FileSystem::MemoryFile.an_executable(cmd) }

        before do
          Oregano[:autosign] = cmd

          Oregano::SSL::CertificateAuthority::AutosignCommand.stubs(:new).returns autosign_cmd
        end

        it "autosigns the CSR if the autosign command returned true" do
          Oregano::FileSystem.overlay(autosign_executable) do
            autosign_cmd.expects(:allowed?).with(csr).returns true

            @ca.expects(:sign).with('host')
            @ca.autosign(csr)
          end
        end

        it "doesn't autosign the CSR if the autosign_command returned false" do
          Oregano::FileSystem.overlay(autosign_executable) do
            autosign_cmd.expects(:allowed?).with(csr).returns false

            @ca.expects(:sign).never
            @ca.autosign(csr)
          end
        end
      end
    end
  end

  describe "when managing certificate clients" do
    before do
      Oregano.settings.stubs(:use)

      Oregano::SSL::CertificateAuthority.any_instance.stubs(:password?).returns true

      stub_ca_host

      Oregano::SSL::Host.expects(:new).returns @host
      Oregano::SSL::CertificateAuthority.any_instance.stubs(:host).returns @host

      @cacert = mock 'certificate'
      @cacert.stubs(:content).returns "cacertificate"
      @ca = Oregano::SSL::CertificateAuthority.new
    end

    it "should be able to list waiting certificate requests" do
      req1 = stub 'req1', :name => "one"
      req2 = stub 'req2', :name => "two"
      Oregano::SSL::CertificateRequest.indirection.expects(:search).with("*").returns [req1, req2]

      expect(@ca.waiting?).to eq(%w{one two})
    end

    it "should delegate removing hosts to the Host class" do
      Oregano::SSL::Host.expects(:destroy).with("myhost")

      @ca.destroy("myhost")
    end

    it "should be able to verify certificates" do
      expect(@ca).to respond_to(:verify)
    end

    it "should list certificates as the sorted list of all existing signed certificates" do
      cert1 = stub 'cert1', :name => "cert1"
      cert2 = stub 'cert2', :name => "cert2"
      Oregano::SSL::Certificate.indirection.expects(:search).with("*").returns [cert1, cert2]
      expect(@ca.list).to eq(%w{cert1 cert2})
    end

    it "should list the full certificates" do
      cert1 = stub 'cert1', :name => "cert1"
      cert2 = stub 'cert2', :name => "cert2"
      Oregano::SSL::Certificate.indirection.expects(:search).with("*").returns [cert1, cert2]
      expect(@ca.list_certificates).to eq([cert1, cert2])
    end

    it "should print a deprecation when using #list_certificates" do
      Oregano::SSL::Certificate.indirection.stubs(:search).with("*").returns [:foo, :bar]
      Oregano.expects(:deprecation_warning).with(regexp_matches(/list_certificates is deprecated/))
      @ca.list_certificates
    end

    describe "and printing certificates" do
      it "should return nil if the certificate cannot be found" do
        Oregano::SSL::Certificate.indirection.expects(:find).with("myhost").returns nil
        expect(@ca.print("myhost")).to be_nil
      end

      it "should print certificates by calling :to_text on the host's certificate" do
        cert1 = stub 'cert1', :name => "cert1", :to_text => "mytext"
        Oregano::SSL::Certificate.indirection.expects(:find).with("myhost").returns cert1
        expect(@ca.print("myhost")).to eq("mytext")
      end
    end

    describe "and fingerprinting certificates" do
      before :each do
        @cert = stub 'cert', :name => "cert", :fingerprint => "DIGEST"
        Oregano::SSL::Certificate.indirection.stubs(:find).with("myhost").returns @cert
        Oregano::SSL::CertificateRequest.indirection.stubs(:find).with("myhost")
      end

      it "should raise an error if the certificate or CSR cannot be found" do
        Oregano::SSL::Certificate.indirection.expects(:find).with("myhost").returns nil
        Oregano::SSL::CertificateRequest.indirection.expects(:find).with("myhost").returns nil
        expect { @ca.fingerprint("myhost") }.to raise_error(ArgumentError, /Could not find a certificate/)
      end

      it "should try to find a CSR if no certificate can be found" do
        Oregano::SSL::Certificate.indirection.expects(:find).with("myhost").returns nil
        Oregano::SSL::CertificateRequest.indirection.expects(:find).with("myhost").returns @cert
        @cert.expects(:fingerprint)
        @ca.fingerprint("myhost")
      end

      it "should delegate to the certificate fingerprinting" do
        @cert.expects(:fingerprint)
        @ca.fingerprint("myhost")
      end

      it "should propagate the digest algorithm to the certificate fingerprinting system" do
        @cert.expects(:fingerprint).with(:digest)
        @ca.fingerprint("myhost", :digest)
      end
    end

    describe "and verifying certificates" do
      let(:cacert) { File.expand_path("/ca/cert") }
      before do
        @store = stub 'store', :verify => true, :add_file => nil, :purpose= => nil, :add_crl => true, :flags= => nil

        OpenSSL::X509::Store.stubs(:new).returns @store

        @cert = stub 'cert', :content => "mycert"
        Oregano::SSL::Certificate.indirection.stubs(:find).returns @cert

        @crl = stub('crl', :content => "mycrl")

        @ca.stubs(:crl).returns @crl
      end

      it "should fail if the host's certificate cannot be found" do
        Oregano::SSL::Certificate.indirection.expects(:find).with("me").returns(nil)

        expect { @ca.verify("me") }.to raise_error(ArgumentError)
      end

      it "should create an SSL Store to verify" do
        OpenSSL::X509::Store.expects(:new).returns @store

        @ca.verify("me")
      end

      it "should add the CA Certificate to the store" do
        Oregano[:cacert] = cacert
        @store.expects(:add_file).with cacert

        @ca.verify("me")
      end

      it "should add the CRL to the store if the crl is enabled" do
        @store.expects(:add_crl).with "mycrl"

        @ca.verify("me")
      end

      it "should set the store purpose to OpenSSL::X509::PURPOSE_SSL_CLIENT" do
        Oregano[:cacert] = cacert
        @store.expects(:add_file).with cacert

        @ca.verify("me")
      end

      it "should set the store flags to check the crl" do
        @store.expects(:flags=).with OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK

        @ca.verify("me")
      end

      it "should use the store to verify the certificate" do
        @cert.expects(:content).returns "mycert"

        @store.expects(:verify).with("mycert").returns true

        @ca.verify("me")
      end

      it "should fail if the verification returns false" do
        @cert.expects(:content).returns "mycert"

        @store.expects(:verify).with("mycert").returns false
        @store.expects(:error)
        @store.expects(:error_string)

        expect { @ca.verify("me") }.to raise_error(Oregano::SSL::CertificateAuthority::CertificateVerificationError)
      end

      describe "certificate_is_alive?" do
        it "should return false if verification fails" do
          @cert.expects(:content).returns "mycert"

          @store.expects(:verify).with("mycert").returns false

          expect(@ca.certificate_is_alive?(@cert)).to be_falsey
        end

        it "should return true if verification passes" do
          @cert.expects(:content).returns "mycert"

          @store.expects(:verify).with("mycert").returns true

          expect(@ca.certificate_is_alive?(@cert)).to be_truthy
        end

        it "should use a cached instance of the x509 store" do
          OpenSSL::X509::Store.stubs(:new).returns(@store).once

          @cert.expects(:content).returns "mycert"

          @store.expects(:verify).with("mycert").returns true

          @ca.certificate_is_alive?(@cert)
          @ca.certificate_is_alive?(@cert)
        end

        it "should be deprecated" do
          Oregano.expects(:deprecation_warning).with(regexp_matches(/certificate_is_alive\? is deprecated/))
          @ca.certificate_is_alive?(@cert)
        end
      end
    end

    describe "and revoking certificates" do
      before do
        @crl = mock 'crl'
        @ca.stubs(:crl).returns @crl

        @ca.stubs(:next_serial).returns 10

        @real_cert = stub 'real_cert', :serial => 15
        @cert = stub 'cert', :content => @real_cert
        Oregano::SSL::Certificate.indirection.stubs(:find).returns @cert

      end

      it "should fail if the certificate revocation list is disabled" do
        @ca.stubs(:crl).returns false

        expect { @ca.revoke('ca_testing') }.to raise_error(ArgumentError)

      end

      it "should delegate the revocation to its CRL" do
        @ca.crl.expects(:revoke)

        @ca.revoke('host')
      end

      it "should get the serial number from the local certificate if it exists" do
        @ca.crl.expects(:revoke).with { |serial, key| serial == 15 }

        Oregano::SSL::Certificate.indirection.expects(:find).with("host").returns @cert

        @ca.revoke('host')
      end

      it "should get the serial number from inventory if no local certificate exists" do
        real_cert = stub 'real_cert', :serial => 15
        cert = stub 'cert', :content => real_cert
        Oregano::SSL::Certificate.indirection.expects(:find).with("host").returns nil

        @ca.inventory.expects(:serials).with("host").returns [16]

        @ca.crl.expects(:revoke).with { |serial, key| serial == 16 }
        @ca.revoke('host')
      end

      it "should revoke all serials matching a name" do
        real_cert = stub 'real_cert', :serial => 15
        cert = stub 'cert', :content => real_cert
        Oregano::SSL::Certificate.indirection.expects(:find).with("host").returns nil

        @ca.inventory.expects(:serials).with("host").returns [16, 20, 25]

        @ca.crl.expects(:revoke).with { |serial, key| serial == 16 }
        @ca.crl.expects(:revoke).with { |serial, key| serial == 20 }
        @ca.crl.expects(:revoke).with { |serial, key| serial == 25 }
        @ca.revoke('host')
      end

      it "should raise an error if no certificate match" do
        real_cert = stub 'real_cert', :serial => 15
        cert = stub 'cert', :content => real_cert
        Oregano::SSL::Certificate.indirection.expects(:find).with("host").returns nil

        @ca.inventory.expects(:serials).with("host").returns []

        @ca.crl.expects(:revoke).never
        expect { @ca.revoke('host') }.to raise_error(ArgumentError, /Could not find a serial number for host/)
      end

      context "revocation by serial number (#16798)" do
        it "revokes when given a lower case hexadecimal formatted string" do
          @ca.crl.expects(:revoke).with { |serial, key| serial == 15 }
          Oregano::SSL::Certificate.indirection.expects(:find).with("0xf").returns nil

          @ca.revoke('0xf')
        end

        it "revokes when given an upper case hexadecimal formatted string" do
          @ca.crl.expects(:revoke).with { |serial, key| serial == 15 }
          Oregano::SSL::Certificate.indirection.expects(:find).with("0xF").returns nil

          @ca.revoke('0xF')
        end

        it "handles very large serial numbers" do
          bighex = '0x4000000000000000000000000000000000000000'
          bighex_int = 365375409332725729550921208179070754913983135744

          @ca.crl.expects(:revoke).with(bighex_int, anything)
          Oregano::SSL::Certificate.indirection.expects(:find).with(bighex).returns nil

          @ca.revoke(bighex)
        end
      end
    end

    it "should be able to generate a complete new SSL host" do
      expect(@ca).to respond_to(:generate)
    end
  end
end

require 'oregano/indirector/memory'

module CertificateAuthorityGenerateSpecs
describe "CertificateAuthority.generate" do

  def expect_to_increment_serial_file
    Oregano.settings.setting(:serial).expects(:exclusive_open)
  end

  def expect_to_sign_a_cert
    expect_to_increment_serial_file
  end

  def expect_to_write_the_ca_password
    Oregano.settings.setting(:capass).expects(:open).with('w:ASCII')
  end

  def expect_ca_initialization
    expect_to_write_the_ca_password
    expect_to_sign_a_cert
  end

  INDIRECTED_CLASSES = [
    Oregano::SSL::Certificate,
    Oregano::SSL::CertificateRequest,
    Oregano::SSL::CertificateRevocationList,
    Oregano::SSL::Key,
  ]

  INDIRECTED_CLASSES.each do |const|
    class const::Memory < Oregano::Indirector::Memory

      # @return Array of all the indirector's values
      #
      # This mirrors Oregano::Indirector::SslFile#search which returns all files
      # in the directory.
      def search(request)
        return @instances.values
      end
    end
  end

  before do
    Oregano::SSL::Inventory.stubs(:new).returns(stub("Inventory", :add => nil))
    INDIRECTED_CLASSES.each { |const| const.indirection.terminus_class = :memory }
  end

  after do
    INDIRECTED_CLASSES.each do |const|
      const.indirection.terminus_class = :file
      const.indirection.termini.clear
    end
  end

  describe "when generating certificates" do
    let(:ca) { Oregano::SSL::CertificateAuthority.new }

    before do
      expect_ca_initialization
    end

    it "should fail if a certificate already exists for the host" do
      cert = Oregano::SSL::Certificate.new('pre.existing')
      Oregano::SSL::Certificate.indirection.save(cert)
      expect { ca.generate(cert.name) }.to raise_error(ArgumentError, /a certificate already exists/i)
    end

    describe "that do not yet exist" do
      let(:cn) { "new.host" }

      def expect_cert_does_not_exist(cn)
        expect( Oregano::SSL::Certificate.indirection.find(cn) ).to be_nil
      end

      before do
        expect_to_sign_a_cert
        expect_cert_does_not_exist(cn)
      end

      it "should return the created certificate" do
        cert = ca.generate(cn)
        expect( cert ).to be_kind_of(Oregano::SSL::Certificate)
        expect( cert.name ).to eq(cn)
      end

      it "should not have any subject_alt_names by default" do
        cert = ca.generate(cn)
        expect( cert.subject_alt_names ).to be_empty
      end

      it "should have subject_alt_names if passed dns_alt_names" do
        cert = ca.generate(cn, :dns_alt_names => 'foo,bar')
        expect( cert.subject_alt_names ).to match_array(["DNS:#{cn}",'DNS:foo','DNS:bar'])
      end

      context "if autosign is false" do
        before do
          Oregano[:autosign] = false
        end

        it "should still generate and explicitly sign the request" do
          cert = nil
          cert = ca.generate(cn)
          expect(cert.name).to eq(cn)
        end
      end

      context "if autosign is true (Redmine #6112)" do

        def run_mode_must_be_master_for_autosign_to_be_attempted
          Oregano.stubs(:run_mode).returns(Oregano::Util::RunMode[:master])
        end

        before do
          Oregano[:autosign] = true
          run_mode_must_be_master_for_autosign_to_be_attempted
          Oregano::Util::Log.level = :info
        end

        it "should generate a cert without attempting to sign again" do
          cert = ca.generate(cn)
          expect(cert.name).to eq(cn)
          expect(@logs.map(&:message)).to include("Autosigning #{cn}")
        end
      end
    end
  end
end
end
