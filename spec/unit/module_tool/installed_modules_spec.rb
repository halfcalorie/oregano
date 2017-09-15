require 'spec_helper'
require 'oregano/module_tool/installed_modules'
require 'oregano_spec/modules'

describe Oregano::ModuleTool::InstalledModules do
  include OreganoSpec::Files

  around do |example|
    dir = tmpdir("deep_path")

    FileUtils.mkdir_p(@modpath = File.join(dir, "modpath"))

    @env = Oregano::Node::Environment.create(:env, [@modpath])
    Oregano.override(:current_environment => @env) do
      example.run
    end
  end

  it 'works when given a semantic version' do
    mod = OreganoSpec::Modules.create('goodsemver', @modpath, :metadata => {:version => '1.2.3'})
    installed = described_class.new(@env)
    expect(installed.modules["oreganolabs-#{mod.name}"].version).to eq(SemanticOregano::Version.parse('1.2.3'))
  end

  it 'defaults when not given a semantic version' do
    mod = OreganoSpec::Modules.create('badsemver', @modpath, :metadata => {:version => 'banana'})
    Oregano.expects(:warning).with(regexp_matches(/Semantic Version/))
    installed = described_class.new(@env)
    expect(installed.modules["oreganolabs-#{mod.name}"].version).to eq(SemanticOregano::Version.parse('0.0.0'))
  end

  it 'defaults when not given a full semantic version' do
    mod = OreganoSpec::Modules.create('badsemver', @modpath, :metadata => {:version => '1.2'})
    Oregano.expects(:warning).with(regexp_matches(/Semantic Version/))
    installed = described_class.new(@env)
    expect(installed.modules["oreganolabs-#{mod.name}"].version).to eq(SemanticOregano::Version.parse('0.0.0'))
  end

  it 'still works if there is an invalid version in one of the modules' do
    mod1 = OreganoSpec::Modules.create('badsemver', @modpath, :metadata => {:version => 'banana'})
    mod2 = OreganoSpec::Modules.create('goodsemver', @modpath, :metadata => {:version => '1.2.3'})
    mod3 = OreganoSpec::Modules.create('notquitesemver', @modpath, :metadata => {:version => '1.2'})
    Oregano.expects(:warning).with(regexp_matches(/Semantic Version/)).twice
    installed = described_class.new(@env)
    expect(installed.modules["oreganolabs-#{mod1.name}"].version).to eq(SemanticOregano::Version.parse('0.0.0'))
    expect(installed.modules["oreganolabs-#{mod2.name}"].version).to eq(SemanticOregano::Version.parse('1.2.3'))
    expect(installed.modules["oreganolabs-#{mod3.name}"].version).to eq(SemanticOregano::Version.parse('0.0.0'))
  end
end
