#! /usr/bin/env ruby

require 'spec_helper'
require 'oregano_spec/handler'
require 'oregano/network/http'
require 'oregano/version'

describe Oregano::Network::HTTP::API do
  def respond(text)
    lambda { |req, res| res.respond_with(200, "text/plain", text) }
  end

  describe "#not_found" do
    let(:response) { Oregano::Network::HTTP::MemoryResponse.new }

    let(:routes) {
      Oregano::Network::HTTP::Route.path(Regexp.new("foo")).
      any.
      chain(Oregano::Network::HTTP::Route.path(%r{^/bar$}).get(respond("bar")),
            Oregano::Network::HTTP::API.not_found)
    }

    it "mounts the chained routes" do
      request = Oregano::Network::HTTP::Request.from_hash(:path => "foo/bar")
      routes.process(request, response)

      expect(response.code).to eq(200)
      expect(response.body).to eq("bar")
    end

    it "responds to unknown paths with a 404" do
      request = Oregano::Network::HTTP::Request.from_hash(:path => "foo/unknown")

      expect do
        routes.process(request, response)
      end.to raise_error(Oregano::Network::HTTP::Error::HTTPNotFoundError)
    end
  end

  describe "Oregano API" do
    let(:handler) { OreganoSpec::Handler.new(Oregano::Network::HTTP::API.master_routes,
                                            Oregano::Network::HTTP::API.ca_routes,
                                            Oregano::Network::HTTP::API.not_found_upgrade) }

    let(:master_prefix) { Oregano::Network::HTTP::MASTER_URL_PREFIX }
    let(:ca_prefix) { Oregano::Network::HTTP::CA_URL_PREFIX }

    it "raises a not-found error for non-CA or master routes and suggests an upgrade" do
      req = Oregano::Network::HTTP::Request.from_hash(:path => "/unknown")
      res = {}
      handler.process(req, res)
      expect(res[:status]).to eq(404)
      expect(res[:body]).to include("Oregano version: #{Oregano.version}")
    end

    describe "when processing Oregano 3 routes" do
      it "gives an upgrade message for master routes" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "/production/node/foo")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("Oregano version: #{Oregano.version}")
        expect(res[:body]).to include("Supported /oregano API versions: #{Oregano::Network::HTTP::MASTER_URL_VERSIONS}")
        expect(res[:body]).to include("Supported /oregano-ca API versions: #{Oregano::Network::HTTP::CA_URL_VERSIONS}")
      end

      it "gives an upgrade message for CA routes" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "/production/certificate/foo")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("Oregano version: #{Oregano.version}")
        expect(res[:body]).to include("Supported /oregano API versions: #{Oregano::Network::HTTP::MASTER_URL_VERSIONS}")
        expect(res[:body]).to include("Supported /oregano-ca API versions: #{Oregano::Network::HTTP::CA_URL_VERSIONS}")
      end
    end

    describe "when processing master routes" do
      it "responds to v3 indirector requests" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/v3/node/foo",
                                                       :params => {:environment => "production"},
                                                       :headers => {'accept' => "application/json"})
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(200)
      end

      it "responds to v3 environments requests" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/v3/environments")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(200)
      end

      it "responds with a not found error to non-v3 requests and does not suggest an upgrade" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_prefix}/unknown")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("No route for GET #{master_prefix}/unknown")
        expect(res[:body]).not_to include("Oregano version: #{Oregano.version}")
      end
    end

    describe "when processing CA routes" do
      it "responds to v1 indirector requests" do
        Oregano::SSL::Certificate.indirection.stubs(:find).returns "foo"
        req = Oregano::Network::HTTP::Request.from_hash(:path => "#{ca_prefix}/v1/certificate/foo",
                                                       :params => {:environment => "production"},
                                                       :headers => {'accept' => "s"})
        res = {}
        handler.process(req, res)
        expect(res[:body]).to eq("foo")
        expect(res[:status]).to eq(200)
      end

      it "responds with a not found error to non-v1 requests and does not suggest an upgrade" do
        req = Oregano::Network::HTTP::Request.from_hash(:path => "#{ca_prefix}/unknown")
        res = {}
        handler.process(req, res)
        expect(res[:status]).to eq(404)
        expect(res[:body]).to include("No route for GET #{ca_prefix}/unknown")
        expect(res[:body]).not_to include("Oregano version: #{Oregano.version}")
      end
    end
  end
end
