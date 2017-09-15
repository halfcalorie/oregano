require 'spec_helper'
require 'oregano/pops'
require 'oregano/loaders'

describe "the versioncmp function" do

  before(:all) do
    loaders = Oregano::Pops::Loaders.new(Oregano::Node::Environment.create(:testing, []))
    Oregano.push_context({:loaders => loaders}, "test-examples")
  end

  after(:all) do
    Oregano::Pops::Loaders.clear
    Oregano::pop_context()
  end

  def versioncmp(*args)
    Oregano.lookup(:loaders).oregano_system_loader.load(:function, 'versioncmp').call({}, *args)
  end

  let(:type_parser) { Oregano::Pops::Types::TypeParser.singleton }

  it 'should raise an Error if there is less than 2 arguments' do
    expect { versioncmp('a,b') }.to raise_error(/expects 2 arguments, got 1/)
  end

  it 'should raise an Error if there is more than 2 arguments' do
    expect { versioncmp('a,b','foo', 'bar') }.to raise_error(/expects 2 arguments, got 3/)
  end

  it "should call Oregano::Util::Package.versioncmp (included in scope)" do
    Oregano::Util::Package.expects(:versioncmp).with('1.2', '1.3').returns(-1)

    expect(versioncmp('1.2', '1.3')).to eq -1
  end
end
