#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/network/http'

describe Oregano::Network::HTTP do
  it 'defines an http_pool context' do
    pool = Oregano.lookup(:http_pool)
    expect(pool).to be_a(Oregano::Network::HTTP::NoCachePool)
  end
end
