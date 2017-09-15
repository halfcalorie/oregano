require 'spec_helper'
require 'oregano_spec/files'
require 'oregano/pops'
require 'oregano/loaders'
require 'oregano_spec/compiler'

describe 'FileBased module loader' do
  include OreganoSpec::Files

  let(:static_loader) { Oregano::Pops::Loader::StaticLoader.new() }
  let(:loaders) { Oregano::Pops::Loaders.new(Oregano::Node::Environment.create(:testing, [])) }

  it 'can load a 4x function API ruby function in global name space' do
    module_dir = dir_containing('testmodule', {
      'lib' => {
        'oregano' => {
          'functions' => {
            'foo4x.rb' => <<-CODE
               Oregano::Functions.create_function(:foo4x) do
                 def foo4x()
                   'yay'
                 end
               end
            CODE
          }
            }
          }
        })

    module_loader = Oregano::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, loaders, 'testmodule', module_dir)
    function = module_loader.load_typed(typed_name(:function, 'foo4x')).value

    expect(function.class.name).to eq('foo4x')
    expect(function.is_a?(Oregano::Functions::Function)).to eq(true)
  end

  it 'can load a 4x function API ruby function in qualified name space' do
    module_dir = dir_containing('testmodule', {
      'lib' => {
        'oregano' => {
          'functions' => {
            'testmodule' => {
              'foo4x.rb' => <<-CODE
                 Oregano::Functions.create_function('testmodule::foo4x') do
                   def foo4x()
                     'yay'
                   end
                 end
              CODE
              }
            }
          }
      }})

    module_loader = Oregano::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, loaders, 'testmodule', module_dir)
    function = module_loader.load_typed(typed_name(:function, 'testmodule::foo4x')).value
    expect(function.class.name).to eq('testmodule::foo4x')
    expect(function.is_a?(Oregano::Functions::Function)).to eq(true)
  end

  it 'system loader has itself as private loader' do
    module_loader = loaders.oregano_system_loader
    expect(module_loader.private_loader).to be(module_loader)
  end

  it 'makes parent loader win over entries in child' do
    module_dir = dir_containing('testmodule', {
      'lib' => { 'oregano' => { 'functions' => { 'testmodule' => {
        'foo.rb' => <<-CODE
           Oregano::Functions.create_function('testmodule::foo') do
             def foo()
               'yay'
             end
           end
        CODE
      }}}}})
    module_loader = Oregano::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, loaders, 'testmodule', module_dir)

    module_dir2 = dir_containing('testmodule2', {
      'lib' => { 'oregano' => { 'functions' => { 'testmodule2' => {
        'foo.rb' => <<-CODE
           raise "should not get here"
        CODE
      }}}}})
    module_loader2 = Oregano::Pops::Loader::ModuleLoaders::FileBased.new(module_loader, loaders, 'testmodule2', module_dir2, 'test2')

    function = module_loader2.load_typed(typed_name(:function, 'testmodule::foo')).value

    expect(function.class.name).to eq('testmodule::foo')
    expect(function.is_a?(Oregano::Functions::Function)).to eq(true)
  end

  def typed_name(type, name)
    Oregano::Pops::Loader::TypedName.new(type, name)
  end

  context 'module function and class using a module type alias' do
    include OreganoSpec::Compiler

    let(:modules) do
      {
        'mod' => {
          'functions' => {
            'afunc.pp' => <<-PUPPET.unindent
              function mod::afunc(Mod::Analias $v) {
                notice($v)
              }
          PUPPET
          },
          'types' => {
            'analias.pp' => <<-PUPPET.unindent
               type Mod::Analias = Enum[a,b]
               PUPPET
          },
          'manifests' => {
            'init.pp' => <<-PUPPET.unindent
              class mod(Mod::Analias $v) {
                notify { $v: }
              }
              PUPPET
          }
        }
      }
    end

    let(:testing_env) do
      {
        'testing' => {
          'modules' => modules
        }
      }
    end

    let(:environments_dir) { Oregano[:environmentpath] }

    let(:testing_env_dir) do
      dir_contained_in(environments_dir, testing_env)
      env_dir = File.join(environments_dir, 'testing')
      OreganoSpec::Files.record_tmp(env_dir)
      env_dir
    end

    let(:env) { Oregano::Node::Environment.create(:testing, [File.join(testing_env_dir, 'modules')]) }
    let(:node) { Oregano::Node.new('test', :environment => env) }

    # The call to mod:afunc will load the function, and as a consequence, make an attempt to load
    # the parameter type Mod::Analias. That load in turn, will trigger the Runtime3TypeLoader which
    # will load the manifests in Mod. The init.pp manifest also references the Mod::Analias parameter
    # which results in a recursive call to the same loader. This test asserts that this recursive
    # call is handled OK.
    # See PUP-7391 for more info.
    it 'should handle a recursive load' do
      expect(eval_and_collect_notices("mod::afunc('b')", node)).to eql(['b'])
    end
  end
end
