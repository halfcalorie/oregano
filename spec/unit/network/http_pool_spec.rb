#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/network/http_pool'

describe Oregano::Network::HttpPool do
  before :each do
    Oregano::SSL::Key.indirection.terminus_class = :memory
    Oregano::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  describe "when managing http instances" do
    it "should return an http instance created with the passed host and port" do
      http = Oregano::Network::HttpPool.http_instance("me", 54321)
      expect(http).to be_an_instance_of Oregano::Network::HTTP::Connection
      expect(http.address).to eq('me')
      expect(http.port).to    eq(54321)
    end

    it "should support using an alternate http client implementation" do
      begin
        class FooClient
          def initialize(host, port, options = {})
            @host = host
            @port = port
          end
          attr_reader :host, :port
        end

        orig_class = Oregano::Network::HttpPool.http_client_class
        Oregano::Network::HttpPool.http_client_class = FooClient
        http = Oregano::Network::HttpPool.http_instance("me", 54321)
        expect(http).to be_an_instance_of FooClient
        expect(http.host).to eq('me')
        expect(http.port).to eq(54321)
      ensure
        Oregano::Network::HttpPool.http_client_class = orig_class
      end
    end

    it "should enable ssl on the http instance by default" do
      expect(Oregano::Network::HttpPool.http_instance("me", 54321)).to be_use_ssl
    end

    it "can set ssl using an option" do
      expect(Oregano::Network::HttpPool.http_instance("me", 54321, false)).not_to be_use_ssl
      expect(Oregano::Network::HttpPool.http_instance("me", 54321, true)).to be_use_ssl
    end

    describe 'peer verification' do
      def setup_standard_ssl_configuration
        ca_cert_file = File.expand_path('/path/to/ssl/certs/ca_cert.pem')

        Oregano[:ssl_client_ca_auth] = ca_cert_file
        Oregano::FileSystem.stubs(:exist?).with(ca_cert_file).returns(true)
      end

      def setup_standard_hostcert
        host_cert_file = File.expand_path('/path/to/ssl/certs/host_cert.pem')
        Oregano::FileSystem.stubs(:exist?).with(host_cert_file).returns(true)

        Oregano[:hostcert] = host_cert_file
      end

      def setup_standard_ssl_host
        cert = stub('cert', :content => 'real_cert')
        key  = stub('key',  :content => 'real_key')
        host = stub('host', :certificate => cert, :key => key, :ssl_store => stub('store'))

        Oregano::SSL::Host.stubs(:localhost).returns(host)
      end

      before do
        setup_standard_ssl_configuration
        setup_standard_hostcert
        setup_standard_ssl_host
      end

      it 'enables peer verification by default' do
        response = Net::HTTPOK.new('1.1', 200, 'body')
        conn = Oregano::Network::HttpPool.http_instance("me", 54321, true)
        conn.expects(:execute_request).with { |http, request| expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER) }.returns(response)
        conn.get('/')
      end

      it 'can disable peer verification' do
        response = Net::HTTPOK.new('1.1', 200, 'body')
        conn = Oregano::Network::HttpPool.http_instance("me", 54321, true, false)
        conn.expects(:execute_request).with { |http, request| expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE) }.returns(response)
        conn.get('/')
      end
    end

    it "should not cache http instances" do
      expect(Oregano::Network::HttpPool.http_instance("me", 54321)).
        not_to equal(Oregano::Network::HttpPool.http_instance("me", 54321))
    end
  end
end
