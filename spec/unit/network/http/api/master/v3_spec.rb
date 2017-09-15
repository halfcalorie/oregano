require 'spec_helper'

require 'oregano/network/http'
require 'oregano_spec/network'

describe Oregano::Network::HTTP::API::Master::V3 do
  include OreganoSpec::Network

  let(:response) { Oregano::Network::HTTP::MemoryResponse.new }
  let(:master_url_prefix) { "#{Oregano::Network::HTTP::MASTER_URL_PREFIX}/v3" }
  let(:master_routes) {
    Oregano::Network::HTTP::Route.
        path(Regexp.new("#{Oregano::Network::HTTP::MASTER_URL_PREFIX}/")).
        any.
        chain(Oregano::Network::HTTP::API::Master::V3.routes)
  }

  it "mounts the environments endpoint" do
    request = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/environments")
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "mounts the environment endpoint" do
    request = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/environment/production")
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "matches only complete routes" do
    request = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/foo/environments")
    expect { master_routes.process(request, response) }.to raise_error(Oregano::Network::HTTP::Error::HTTPNotFoundError)

    request = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/foo/environment/production")
    expect { master_routes.process(request, response) }.to raise_error(Oregano::Network::HTTP::Error::HTTPNotFoundError)
  end

  it "mounts indirected routes" do
    request = Oregano::Network::HTTP::Request.
        from_hash(:path => "#{master_url_prefix}/node/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "application/json"})
    master_routes.process(request, response)

    expect(response.code).to eq(200)
  end

  it "responds to unknown paths by raising not_found_error" do
    request = Oregano::Network::HTTP::Request.from_hash(:path => "#{master_url_prefix}/unknown")

    expect {
      master_routes.process(request, response)
    }.to raise_error(not_found_error)
  end
end
