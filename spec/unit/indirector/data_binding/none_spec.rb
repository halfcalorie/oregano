require 'spec_helper'
require 'oregano/indirector/data_binding/none'

describe Oregano::DataBinding::None do
  it "should be a subclass of the None terminus" do
    expect(Oregano::DataBinding::None.superclass).to equal(Oregano::Indirector::None)
  end

  it "should have documentation" do
    expect(Oregano::DataBinding::None.doc).not_to be_nil
  end

  it "should be registered with the data_binding indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:data_binding)
    expect(Oregano::DataBinding::None.indirection).to equal(indirection)
  end

  it "should have its name set to :none" do
    expect(Oregano::DataBinding::None.name).to eq(:none)
  end

  describe "the behavior of the find method" do
    it "should just throw :no_such_key" do
      data_binding = Oregano::DataBinding::None.new
      expect { data_binding.find('fake_request') }.to throw_symbol(:no_such_key)
    end
  end
end
