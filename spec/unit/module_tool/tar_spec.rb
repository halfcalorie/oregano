require 'spec_helper'
require 'oregano/module_tool/tar'

describe Oregano::ModuleTool::Tar do

  [
    { :name => 'ObscureLinuxDistro', :win => false }, 
    { :name => 'Windows', :win => true }
  ].each do |os|
    it "always prefers minitar if it and zlib are present, even with tar available" do
      Facter.stubs(:value).with('osfamily').returns os[:name]
      Oregano::Util.stubs(:which).with('tar').returns '/usr/bin/tar'
      Oregano::Util::Platform.stubs(:windows?).returns os[:win]
      Oregano.stubs(:features).returns(stub(:minitar? => true, :zlib? => true))

      expect(described_class.instance).to be_a_kind_of Oregano::ModuleTool::Tar::Mini
    end
  end

  it "falls back to tar when minitar not present and not on Windows" do
    Facter.stubs(:value).with('osfamily').returns 'ObscureLinuxDistro'
    Oregano::Util.stubs(:which).with('tar').returns '/usr/bin/tar'
    Oregano::Util::Platform.stubs(:windows?).returns false
    Oregano.stubs(:features).returns(stub(:minitar? => false))

    expect(described_class.instance).to be_a_kind_of Oregano::ModuleTool::Tar::Gnu
  end

  it "fails when there is no possible implementation" do
    Facter.stubs(:value).with('osfamily').returns 'Windows'
    Oregano::Util.stubs(:which).with('tar')
    Oregano::Util::Platform.stubs(:windows?).returns true
    Oregano.stubs(:features).returns(stub(:minitar? => false, :zlib? => false))

    expect { described_class.instance }.to raise_error RuntimeError, /No suitable tar/
  end
end
