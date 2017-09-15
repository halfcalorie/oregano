#! /usr/bin/env ruby
require 'spec_helper'

require 'matchers/json'

describe Oregano::Status do
  include JSONMatchers

  it "should implement find" do
    expect(Oregano::Status.indirection.find( :default )).to be_is_a(Oregano::Status)
    expect(Oregano::Status.indirection.find( :default ).status["is_alive"]).to eq(true)
  end

  it "should default to is_alive is true" do
    expect(Oregano::Status.new.status["is_alive"]).to eq(true)
  end

  it "should return a json hash" do
    expect(Oregano::Status.new.status.to_json).to eq('{"is_alive":true}')
  end

  it "should render to a json hash" do
    expect(JSON::pretty_generate(Oregano::Status.new)).to match(/"is_alive":\s*true/)
  end

  it "should accept a hash from json" do
    status = Oregano::Status.new( { "is_alive" => false } )
    expect(status.status).to eq({ "is_alive" => false })
  end

  it "should have a name" do
    Oregano::Status.new.name
  end

  it "should allow a name to be set" do
    Oregano::Status.new.name = "status"
  end

  it "serializes to JSON that conforms to the status schema" do
    status = Oregano::Status.new
    status.version = Oregano.version

    expect(status.render('json')).to validate_against('api/schemas/status.json')
  end
end
