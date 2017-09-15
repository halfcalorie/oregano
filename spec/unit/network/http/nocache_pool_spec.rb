#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/network/http'
require 'oregano/network/http/connection'

describe Oregano::Network::HTTP::NoCachePool do
  let(:site) { Oregano::Network::HTTP::Site.new('https', 'rubygems.org', 443) }
  let(:verify) { stub('verify', :setup_connection => nil) }

  it 'yields a connection' do
    http  = stub('http')

    factory = Oregano::Network::HTTP::Factory.new
    factory.stubs(:create_connection).returns(http)
    pool = Oregano::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http)
  end

  it 'yields a new connection each time' do
    http1  = stub('http1')
    http2  = stub('http2')

    factory = Oregano::Network::HTTP::Factory.new
    factory.stubs(:create_connection).returns(http1).then.returns(http2)
    pool = Oregano::Network::HTTP::NoCachePool.new(factory)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http1)

    expect { |b|
      pool.with_connection(site, verify, &b)
    }.to yield_with_args(http2)
  end

  it 'has a close method' do
    Oregano::Network::HTTP::NoCachePool.new.close
  end
end
