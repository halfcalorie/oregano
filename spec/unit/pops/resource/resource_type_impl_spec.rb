#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/pops'
require 'oregano_spec/files'
require 'oregano_spec/compiler'

module Oregano::Pops
module Resource
describe "Oregano::Pops::Resource" do
  include OreganoSpec::Compiler

  let!(:pp_parser) { Parser::EvaluatingParser.new }
  let(:loader) { Loader::BaseLoader.new(nil, 'type_parser_unit_test_loader') }
  let(:factory) { TypeFactory }

  context 'when creating resources' do
    let!(:resource_type) { ResourceTypeImpl._pcore_type }

    it 'can create an instance of a ResourceType' do
      code = <<-CODE
        $rt = Oregano::Resource::ResourceType3.new('notify', [], [Oregano::Resource::Param.new(String, 'message')])
        assert_type(Oregano::Resource::ResourceType3, $rt)
        notice('looks like we made it')
      CODE
      rt = nil
      notices = eval_and_collect_notices(code) do |scope, _|
        rt = scope['rt']
      end
      expect(notices).to eq(['looks like we made it'])
      expect(rt).to be_a(ResourceTypeImpl)
      expect(rt.valid_parameter?(:nonesuch)).to be_falsey
      expect(rt.valid_parameter?(:message)).to be_truthy
      expect(rt.valid_parameter?(:loglevel)).to be_truthy
    end
  end


  context 'when used with capability resource with producers/consumers' do
    include OreganoSpec::Files

    let!(:env_name) { 'spec' }
    let!(:env_dir) { tmpdir('environments') }
    let!(:populated_env_dir) do
      dir_contained_in(env_dir, env_name => {
        '.resource_types' => {
          'capability.pp' => <<-PUPPET
            Oregano::Resource::ResourceType3.new(
              'capability',
              [],
              [Oregano::Resource::Param(Any, 'name', true)],
              { /(.*)/ => ['name'] },
              true,
              true)
        PUPPET
        },
        'modules' => {
          'test' => {
            'lib' => {
              'oregano' => {
                'type' => { 'capability.rb' => <<-RUBY
                  Oregano::Type.newtype(:capability, :is_capability => true) do
                    newparam :name, :namevar => true
                    raise Oregano::Error, 'Ruby resource was loaded'
                  end
                RUBY
                }
              }
            }
          }
        }
      })
    end

    let!(:code) { <<-PUPPET }
      define producer() {
        notify { "producer":}
      }

      define consumer() {
        notify { $title:}
      }

      Producer produces Capability {}

      Consumer consumes Capability {}

      producer {x: export => Capability[cap]}
      consumer {x: consume => Capability[cap]}
      consumer {y: require => Capability[cap]}
    PUPPET

    let(:environments) { Oregano::Environments::Directories.new(populated_env_dir, []) }
    let(:env) { Oregano::Node::Environment.create(:'spec', [File.join(env_dir, 'spec', 'modules')]) }
    let(:node) { Oregano::Node.new('test', :environment => env) }
    around(:each) do |example|
      Oregano[:environment] = env_name
      Oregano.override(:environments => environments, :current_environment => env) do
        example.run
      end
      Oregano::Type.rmtype(:capability)
    end

    it 'does not load the Ruby resource' do
      expect { compile_to_catalog(code, node) }.not_to raise_error
    end
  end
end
end
end
