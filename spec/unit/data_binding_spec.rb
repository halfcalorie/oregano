require 'spec_helper'
require 'oregano/data_binding'

describe Oregano::DataBinding do
  describe "when indirecting" do
    it "should default to the 'hiera' data_binding terminus" do
      Oregano::DataBinding.indirection.reset_terminus_class
      expect(Oregano::DataBinding.indirection.terminus_class).to eq(:hiera)
    end
  end
end
