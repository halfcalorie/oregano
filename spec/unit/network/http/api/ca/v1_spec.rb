require 'spec_helper'

require 'oregano/network/http'

describe Oregano::Network::HTTP::API::CA::V1 do
  let(:response) { Oregano::Network::HTTP::MemoryResponse.new }
  let(:ca_url_prefix) { "#{Oregano::Network::HTTP::CA_URL_PREFIX}/v1"}

  let(:ca_routes) {
    Oregano::Network::HTTP::Route.
      path(Regexp.new("#{Oregano::Network::HTTP::CA_URL_PREFIX}/")).
      any.
      chain(Oregano::Network::HTTP::API::CA::V1.routes)
  }

  it "mounts ca routes" do
    Oregano::SSL::Certificate.indirection.stubs(:find).returns "foo"
    request = Oregano::Network::HTTP::Request.
        from_hash(:path => "#{ca_url_prefix}/certificate/foo",
                  :params => {:environment => "production"},
                  :headers => {"accept" => "s"})
    ca_routes.process(request, response)

    expect(response.code).to eq(200)
  end
end
