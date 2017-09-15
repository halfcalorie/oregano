#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Type.type(:service).provider(:windows), '(integration)',
  :if => Oregano.features.microsoft_windows? do

  require 'oregano/util/windows'

  before :each do
    Oregano::Type.type(:service).stubs(:defaultprovider).returns described_class
  end

  context 'should fail querying services that do not exist' do
    let(:service) do
      Oregano::Type.type(:service).new(:name => 'foobarservice1234')
    end

    it "with a Oregano::Error when querying enabled?" do
      expect { service.provider.enabled? }.to raise_error(Oregano::Error)
    end

    it "with a Oregano::Error when querying status" do
      expect { service.provider.status }.to raise_error(Oregano::Error)
    end
  end

  context 'should return valid values when querying a service that does exist' do
    let(:service) do
      # This service should be ubiquitous across all supported Windows platforms
      Oregano::Type.type(:service).new(:name => 'lmhosts')
    end

    it "with a valid enabled? value when asked if enabled" do
      expect([:true, :false, :manual]).to include(service.provider.enabled?)
    end

    it "with a valid status when asked about status" do
      expect([
        :running,
        :'continue pending',
        :'pause pending',
        :paused,
        :running,
        :'start pending',
        :'stop pending',
        :stopped]).to include(service.provider.status)
    end
  end
end
