require 'spec_helper'
require 'oregano/module_tool/applications'
require 'oregano_spec/modules'

describe Oregano::ModuleTool::Applications::Searcher do
  include OreganoSpec::Files

  describe "when searching" do
    let(:forge) { mock 'forge', :host => 'http://nowhe.re' }
    let(:searcher) do
      described_class.new('search_term', forge)
    end

    it "should return results from a forge query when successful" do
      results = 'mock results'
      forge.expects(:search).with('search_term').returns(results)

      search_result = searcher.run
      expect(search_result).to eq({
        :result => :success,
        :answers => results,
      })
    end

    it "should return an error when the forge query throws an exception" do
      forge.expects(:search).with('search_term').raises Oregano::Forge::Errors::ForgeError.new("something went wrong")

      search_result = searcher.run
      expect(search_result).to eq({
        :result => :failure,
        :error => {
          :oneline   => 'something went wrong',
          :multiline => 'something went wrong',
        },
      })
    end
  end
end
