require 'spec_helper'

require 'oregano/node/environment'
require 'oregano/network/http'
require 'matchers/json'

describe Oregano::Network::HTTP::API::Master::V3::Environments do
  include JSONMatchers

  it "responds with all of the available environments" do
    environment = Oregano::Node::Environment.create(:production, ["/first", "/second"], '/manifests')
    loader = Oregano::Environments::Static.new(environment)
    handler = Oregano::Network::HTTP::API::Master::V3::Environments.new(loader)
    response = Oregano::Network::HTTP::MemoryResponse.new

    handler.call(Oregano::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

    expect(response.code).to eq(200)
    expect(response.type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq({
      "search_paths" => loader.search_paths,
      "environments" => {
        "production" => {
          "settings" => {
            "modulepath" => [File.expand_path("/first"), File.expand_path("/second")],
            "manifest" => File.expand_path("/manifests"),
            "environment_timeout" => 0,
            "config_version" => ""
          }
        }
      }
    })
  end

  it "the response conforms to the environments schema for unlimited timeout" do
    conf_stub = stub 'conf_stub'
    conf_stub.expects(:environment_timeout).returns(Float::INFINITY)
    environment = Oregano::Node::Environment.create(:production, [])
    env_loader = Oregano::Environments::Static.new(environment)
    env_loader.expects(:get_conf).with(:production).returns(conf_stub)
    handler = Oregano::Network::HTTP::API::Master::V3::Environments.new(env_loader)
    response = Oregano::Network::HTTP::MemoryResponse.new

    handler.call(Oregano::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end

  it "the response conforms to the environments schema for integer timeout" do
    conf_stub = stub 'conf_stub'
    conf_stub.expects(:environment_timeout).returns(1)
    environment = Oregano::Node::Environment.create(:production, [])
    env_loader = Oregano::Environments::Static.new(environment)
    env_loader.expects(:get_conf).with(:production).returns(conf_stub)
    handler = Oregano::Network::HTTP::API::Master::V3::Environments.new(env_loader)
    response = Oregano::Network::HTTP::MemoryResponse.new

    handler.call(Oregano::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end

end
