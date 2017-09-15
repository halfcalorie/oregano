require 'spec_helper'
require 'oregano_spec/files'
require 'oregano/pops'
require 'oregano/loaders'

describe 'loader paths' do
  include OreganoSpec::Files

  let(:static_loader) { Oregano::Pops::Loader::StaticLoader.new() }
  let(:unused_loaders) { Oregano::Pops::Loaders.new(Oregano::Node::Environment.create(:'*test*', [])) }

  it 'module loader has smart-paths that prunes unavailable paths' do
    module_dir = dir_containing('testmodule', {'lib' => {'oregano' => {'functions' =>
      {'foo.rb' =>
        'Oregano::Functions.create_function("testmodule::foo") {
          def foo; end;
        }'
      }
    }}})
    module_loader = Oregano::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, unused_loaders, 'testmodule', module_dir)

    effective_paths = module_loader.smart_paths.effective_paths(:function)

    expect(effective_paths.size).to be_eql(1)
    expect(effective_paths[0].generic_path).to be_eql(File.join(module_dir, 'lib', 'oregano', 'functions'))
  end

  it 'all function smart-paths produces entries if they exist' do
    module_dir = dir_containing('testmodule', {
      'lib' => {
        'oregano' => {
          'functions' => {'foo4x.rb' => 'ignored in this test'},
        }}})
    module_loader = Oregano::Pops::Loader::ModuleLoaders.module_loader_from(static_loader, unused_loaders, 'testmodule', module_dir)

    effective_paths = module_loader.smart_paths.effective_paths(:function)

    expect(effective_paths.size).to eq(1)
    expect(module_loader.path_index.size).to eq(1)
    path_index = module_loader.path_index
    expect(path_index).to include(File.join(module_dir, 'lib', 'oregano', 'functions', 'foo4x.rb'))
  end
end
