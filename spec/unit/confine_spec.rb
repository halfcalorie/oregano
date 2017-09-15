#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/confine'

describe Oregano::Confine do
  it "should require a value" do
    expect { Oregano::Confine.new }.to raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    expect(Oregano::Confine.new("/some/file").values).to be_instance_of(Array)
  end

  it "should have a 'true' test" do
    expect(Oregano::Confine.test(:true)).to be_instance_of(Class)
  end

  it "should have a 'false' test" do
    expect(Oregano::Confine.test(:false)).to be_instance_of(Class)
  end

  it "should have a 'feature' test" do
    expect(Oregano::Confine.test(:feature)).to be_instance_of(Class)
  end

  it "should have an 'exists' test" do
    expect(Oregano::Confine.test(:exists)).to be_instance_of(Class)
  end

  it "should have a 'variable' test" do
    expect(Oregano::Confine.test(:variable)).to be_instance_of(Class)
  end

  describe "when testing all values" do
    before do
      @confine = Oregano::Confine.new(%w{a b c})
      @confine.label = "foo"
    end

    it "should be invalid if any values fail" do
      @confine.stubs(:pass?).returns true
      @confine.expects(:pass?).with("b").returns false
      expect(@confine).not_to be_valid
    end

    it "should be valid if all values pass" do
      @confine.stubs(:pass?).returns true
      expect(@confine).to be_valid
    end

    it "should short-cut at the first failing value" do
      @confine.expects(:pass?).once.returns false
      @confine.valid?
    end

    it "should log failing confines with the label and message" do
      @confine.stubs(:pass?).returns false
      @confine.expects(:message).returns "My message"
      @confine.expects(:label).returns "Mylabel"
      Oregano.expects(:debug).with("Mylabel: My message")
      @confine.valid?
    end
  end

  describe "when testing the result of the values" do
    before { @confine = Oregano::Confine.new(%w{a b c d}) }

    it "should return an array with the result of the test for each value" do
      @confine.stubs(:pass?).returns true
      @confine.expects(:pass?).with("b").returns false
      @confine.expects(:pass?).with("d").returns false

      expect(@confine.result).to eq([true, false, true, false])
    end
  end
end
