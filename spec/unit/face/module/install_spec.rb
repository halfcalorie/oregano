require 'spec_helper'
require 'oregano/face'
require 'oregano/module_tool'

describe "oregano module install" do
  include OreganoSpec::Files

  describe "action" do
    let(:name)        { stub(:name) }
    let(:target_dir)  { tmpdir('module install face action') }
    let(:options)     { { :target_dir => target_dir } }

    it 'should invoke the Installer app' do
      Oregano::ModuleTool.expects(:set_option_defaults).with(options)
      Oregano::ModuleTool::Applications::Installer.expects(:run).with do |*args|
        mod, target, opts = args

        expect(mod).to eql(name)
        expect(opts).to eql(options)
        expect(target).to be_a(Oregano::ModuleTool::InstallDirectory)
        expect(target.target).to eql(Pathname.new(target_dir))
      end

      Oregano::Face[:module, :current].install(name, options)
    end
  end

  describe "inline documentation" do
    subject { Oregano::Face.find_action(:module, :install) }

    its(:summary)     { should =~ /install.*module/im }
    its(:description) { should =~ /install.*module/im }
    its(:returns)     { should =~ /pathname/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
