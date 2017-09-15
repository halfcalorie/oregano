require 'oregano'
require 'spec_helper'
require 'oregano_spec/compiler'

require 'matchers/resource'

describe 'the call method' do
  include OreganoSpec::Compiler
  include OreganoSpec::Files
  include Matchers::Resource

  context "should be callable as" do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Oregano[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:env) { Oregano::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
    let(:node) { Oregano::Node.new("test", :environment => env) }
    let(:env_dir_files) {
      {
        'modules' => {
          'test' => {
            'functions' => {
              'call_me.pp' => 'function test::call_me() { "called" }'
            }
          }
        }
      }
    }

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      OreganoSpec::Files.record_tmp(env_dir)
      env_dir
    end

    it 'call on a built-in 4x Ruby API function' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[a]')
          $a = call('split', 'a-b-c', '-')
          notify { $a[0]: }
        CODE
    end

    it 'call on a Oregano language function with no arguments' do
      expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[called]')
        notify { test::call_me(): }
        CODE
    end

    it 'call a Ruby 4x API built-in with block' do
      catalog = compile_to_catalog(<<-CODE)
        $a = 'each'
        $b = [1,2,3]
        call($a, $b) |$index, $v| {
          file { "/file_$v": ensure => present }
        }
      CODE

      expect(catalog.resource(:file, "/file_1")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_2")['ensure']).to eq('present')
      expect(catalog.resource(:file, "/file_3")['ensure']).to eq('present')
    end

    it 'call with the calling context' do
      expect(eval_and_collect_notices(<<-CODE)).to eq(['a'])
        class a { call('notice', $title) }
        include a
      CODE
    end

    it 'call on a non-existent function name' do
      expect { compile_to_catalog(<<-CODE) }.to raise_error(Oregano::Error, /Unknown function/)
        $a = call('not_a_function_name')
        notify { $a: }
      CODE
    end
  end
end
