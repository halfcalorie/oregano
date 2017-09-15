#! /usr/bin/env ruby
require 'spec_helper'
require_relative '../pops/parser/parser_rspec_helper'
require 'oregano/resource/capability_finder'

describe Oregano::Resource::CapabilityFinder do
  context 'when OreganoDB is not configured' do
    it 'should error' do
      Oregano::Util.expects(:const_defined?).with('Oreganodb').returns false
      expect { Oregano::Resource::CapabilityFinder.find('production', nil, nil) }.to raise_error(/OreganoDB is not available/)
    end
  end

  context 'when OreganoDB is configured' do
    around(:each) do |example|
      mock_pdb = !Oregano::Util.const_defined?('Oreganodb')
      if mock_pdb
        module Oregano::Util::Oreganodb
          class Http; end
        end
      end
      begin
        Oregano::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
        Oregano.override(:loaders => loaders, :current_environment => env) do
          make_cap_type
          example.run
        end
      ensure
        Oregano::Util.send(:remove_const, 'Oreganodb') if mock_pdb
        Oregano::Type.rmtype(:cap)
        Oregano::Pops::Loaders.clear
      end
    end

    let(:env) { Oregano::Node::Environment.create(:testing, []) }
    let(:loaders) { Oregano::Pops::Loaders.new(env) }

    let(:response_body) { [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}] }
    let(:response) { stub('response', :body => response_body.to_json) }

    def make_cap_type
      Oregano::Type.newtype :cap, :is_capability => true do
        newparam :name
        newparam :host
      end
    end

    describe "when query_oreganodb method is available" do
      it 'should call use the query_oreganodb method if available' do
        Oregano::Util::Oreganodb.expects(:query_oreganodb).returns(response_body)
        Oregano::Util::Oreganodb::Http.expects(:action).never

        result = Oregano::Resource::CapabilityFinder.find('production', nil, Oregano::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end

    describe "when query_oreganodb method is unavailable" do
      before :each do
        Oregano::Util::Oreganodb.stubs(:respond_to?).with(:query_oreganodb).returns false
      end

      it 'should call Oregano::Util::OreganoDB::Http.action' do
        Oregano::Util::Oreganodb::Http.expects(:action).returns(response)
        result = Oregano::Resource::CapabilityFinder.find('production', nil, Oregano::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end

    describe '#find' do
      let(:capability) { Oregano::Resource.new('Cap', 'cap') }
      let(:code_id) { 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe' }

      it 'should search for the resource without including code_id or environment' do
        resources = [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}]
        Oregano::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources

        result = Oregano::Resource::CapabilityFinder.find('production', code_id, Oregano::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end

      it 'should return nil if no resource is found' do
        Oregano::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns []

        result = Oregano::Resource::CapabilityFinder.find('production', code_id, capability)
        expect(result).to be_nil
      end

      describe 'when multiple results are returned for different environments' do
        let(:resources) do
          [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}, "tags"=>["producer:production"]},
           {"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"bhost"}, "tags"=>["producer:other_env"]}]
        end

        before :each do
          Oregano::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources
        end

        it 'should return the resource matching environment' do
          result = Oregano::Resource::CapabilityFinder.find('production', code_id, capability)
          expect(result['host']).to eq('ahost')
        end

        it 'should return nil if no resource matches environment' do
          result = Oregano::Resource::CapabilityFinder.find('bad_env', code_id, capability)
          expect(result).to be_nil
        end
      end

      describe 'when multiple results are returned for the same environment' do
        let(:resources) do
          [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}, "tags"=>["producer:production"]},
           {"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"bhost"}, "tags"=>["producer:production"]}]
        end

        before :each do
          Oregano::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources
        end

        it 'should return the resource matching code_id' do
          Oregano::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"chost"}}]

          result = Oregano::Resource::CapabilityFinder.find('production', code_id, capability)
          expect(result['host']).to eq('chost')
        end

        it 'should fail if no resource matches code_id' do
          Oregano::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns []

          expect { Oregano::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Oregano::Error, /expected exactly one resource but got 2/)
        end

        it 'should fail if multiple resources match code_id' do
          Oregano::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns resources

          expect { Oregano::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Oregano::DevError, /expected exactly one resource but got 2/)
        end

        it 'should fail if no code_id was specified' do
          Oregano::Resource::CapabilityFinder.stubs(:search).with('production', nil, capability).returns resources
          expect { Oregano::Resource::CapabilityFinder.find('production', nil, capability) }.to raise_error(Oregano::DevError, /expected exactly one resource but got 2/)
        end
      end
    end
  end
end
