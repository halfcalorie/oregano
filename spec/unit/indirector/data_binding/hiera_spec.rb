require 'spec_helper'
require 'oregano/indirector/data_binding/hiera'

describe Oregano::DataBinding::Hiera do
  it "should have documentation" do
    expect(Oregano::DataBinding::Hiera.doc).not_to be_nil
  end

  it "should be registered with the data_binding indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:data_binding)
    expect(Oregano::DataBinding::Hiera.indirection).to equal(indirection)
  end

  it "should have its name set to :hiera" do
    expect(Oregano::DataBinding::Hiera.name).to eq(:hiera)
  end

  it_should_behave_like "Hiera indirection", Oregano::DataBinding::Hiera, my_fixture_dir
end
