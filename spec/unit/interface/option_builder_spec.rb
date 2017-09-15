require 'spec_helper'
require 'oregano/interface'

describe Oregano::Interface::OptionBuilder do
  let :face do Oregano::Interface.new(:option_builder_testing, '0.0.1') end

  it "should be able to construct an option without a block" do
    expect(Oregano::Interface::OptionBuilder.build(face, "--foo")).
      to be_an_instance_of Oregano::Interface::Option
  end

  Oregano.settings.each do |name, value|
    it "should fail when option #{name.inspect} already exists in oregano core" do
      expect do
        Oregano::Interface::OptionBuilder.build(face, "--#{name}")
      end.to raise_error ArgumentError, /already defined/
    end
  end

  it "should work with an empty block" do
    option = Oregano::Interface::OptionBuilder.build(face, "--foo") do
      # This block deliberately left blank.
    end

    expect(option).to be_an_instance_of Oregano::Interface::Option
  end

  [:description, :summary].each do |doc|
    it "should support #{doc} declarations" do
      text = "this is the #{doc}"
      option = Oregano::Interface::OptionBuilder.build(face, "--foo") do
        self.send doc, text
      end
      expect(option).to be_an_instance_of Oregano::Interface::Option
      expect(option.send(doc)).to eq(text)
    end
  end

  context "before_action hook" do
    it "should support a before_action hook" do
      option = Oregano::Interface::OptionBuilder.build(face, "--foo") do
        before_action do |a,b,c| :whatever end
      end
      expect(option.before_action).to be_an_instance_of UnboundMethod
    end

    it "should fail if the hook block takes too few arguments" do
      expect do
        Oregano::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |one, two| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should fail if the hook block takes too many arguments" do
      expect do
        Oregano::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |one, two, three, four| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should fail if the hook block takes a variable number of arguments" do
      expect do
        Oregano::Interface::OptionBuilder.build(face, "--foo") do
          before_action do |*blah| true end
        end
      end.to raise_error ArgumentError, /takes three arguments/
    end

    it "should support simple required declarations" do
      opt = Oregano::Interface::OptionBuilder.build(face, "--foo") do
        required
      end
      expect(opt).to be_required
    end

    it "should support arguments to the required property" do
      opt = Oregano::Interface::OptionBuilder.build(face, "--foo") do
        required(false)
      end
      expect(opt).not_to be_required
    end
    
  end
end
