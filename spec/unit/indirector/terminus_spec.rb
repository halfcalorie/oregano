#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/defaults'
require 'oregano/indirector'
require 'oregano/indirector/memory'

describe Oregano::Indirector::Terminus do
  before :all do
    class Oregano::AbstractConcept
      extend Oregano::Indirector
      indirects :abstract_concept
      attr_accessor :name
      def initialize(name = "name")
        @name = name
      end
    end

    class Oregano::AbstractConcept::Freedom < Oregano::Indirector::Code
    end
  end

  after :all do
    # Remove the class, unlinking it from the rest of the system.
    Oregano.send(:remove_const, :AbstractConcept)
  end

  let :terminus_class do Oregano::AbstractConcept::Freedom end
  let :terminus       do terminus_class.new end
  let :indirection    do Oregano::AbstractConcept.indirection end
  let :model          do Oregano::AbstractConcept end

  it "should provide a method for setting terminus class documentation" do
    expect(terminus_class).to respond_to(:desc)
  end

  it "should support a class-level name attribute" do
    expect(terminus_class).to respond_to(:name)
  end

  it "should support a class-level indirection attribute" do
    expect(terminus_class).to respond_to(:indirection)
  end

  it "should support a class-level terminus-type attribute" do
    expect(terminus_class).to respond_to(:terminus_type)
  end

  it "should support a class-level model attribute" do
    expect(terminus_class).to respond_to(:model)
  end

  it "should accept indirection instances as its indirection" do
    # The test is that this shouldn't raise, and should preserve the object
    # instance exactly, hence "equal", not just "==".
    terminus_class.indirection = indirection
    expect(terminus_class.indirection).to equal indirection
  end

  it "should look up indirection instances when only a name has been provided" do
    terminus_class.indirection = :abstract_concept
    expect(terminus_class.indirection).to equal indirection
  end

  it "should fail when provided a name that does not resolve to an indirection" do
    expect {
      terminus_class.indirection = :exploding_whales
    }.to raise_error(ArgumentError, /Could not find indirection instance/)

    # We should still have the default indirection.
    expect(terminus_class.indirection).to equal indirection
  end

  describe "when a terminus instance" do
    it "should return the class's name as its name" do
      expect(terminus.name).to eq(:freedom)
    end

    it "should return the class's indirection as its indirection" do
      expect(terminus.indirection).to equal indirection
    end

    it "should set the instances's type to the abstract terminus type's name" do
      expect(terminus.terminus_type).to eq(:code)
    end

    it "should set the instances's model to the indirection's model" do
      expect(terminus.model).to equal indirection.model
    end
  end

  describe "when managing terminus classes" do
    it "should provide a method for registering terminus classes" do
      expect(Oregano::Indirector::Terminus).to respond_to(:register_terminus_class)
    end

    it "should provide a method for returning terminus classes by name and type" do
      terminus = stub 'terminus_type', :name => :abstract, :indirection_name => :whatever
      Oregano::Indirector::Terminus.register_terminus_class(terminus)
      expect(Oregano::Indirector::Terminus.terminus_class(:whatever, :abstract)).to equal(terminus)
    end

    it "should set up autoloading for any terminus class types requested" do
      Oregano::Indirector::Terminus.expects(:instance_load).with(:test2, "oregano/indirector/test2")
      Oregano::Indirector::Terminus.terminus_class(:test2, :whatever)
    end

    it "should load terminus classes that are not found" do
      # Set up instance loading; it would normally happen automatically
      Oregano::Indirector::Terminus.instance_load :test1, "oregano/indirector/test1"

      Oregano::Indirector::Terminus.instance_loader(:test1).expects(:load).with(:yay)
      Oregano::Indirector::Terminus.terminus_class(:test1, :yay)
    end

    it "should fail when no indirection can be found" do
      Oregano::Indirector::Indirection.expects(:instance).with(:abstract_concept).returns(nil)
      expect {
        class Oregano::AbstractConcept::Physics < Oregano::Indirector::Code
        end
      }.to raise_error(ArgumentError, /Could not find indirection instance/)
    end

    it "should register the terminus class with the terminus base class" do
      Oregano::Indirector::Terminus.expects(:register_terminus_class).with do |type|
        type.indirection_name == :abstract_concept and type.name == :intellect
      end

      begin
        class Oregano::AbstractConcept::Intellect < Oregano::Indirector::Code
        end
      ensure
        Oregano::AbstractConcept.send(:remove_const, :Intellect) rescue nil
      end
    end
  end

  describe "when parsing class constants for indirection and terminus names" do
    before :each do
      Oregano::Indirector::Terminus.stubs(:register_terminus_class)
    end

    let :subclass do
      subclass = mock 'subclass'
      subclass.stubs(:to_s).returns("TestInd::OneTwo")
      subclass.stubs(:mark_as_abstract_terminus)
      subclass
    end

    it "should fail when anonymous classes are used" do
      expect {
        Oregano::Indirector::Terminus.inherited(Class.new)
      }.to raise_error(Oregano::DevError, /Terminus subclasses must have associated constants/)
    end

    it "should use the last term in the constant for the terminus class name" do
      subclass.expects(:name=).with(:one_two)
      subclass.stubs(:indirection=)
      Oregano::Indirector::Terminus.inherited(subclass)
    end

    it "should convert the terminus name to a downcased symbol" do
      subclass.expects(:name=).with(:one_two)
      subclass.stubs(:indirection=)
      Oregano::Indirector::Terminus.inherited(subclass)
    end

    it "should use the second to last term in the constant for the indirection name" do
      subclass.expects(:indirection=).with(:test_ind)
      subclass.stubs(:name=)
      subclass.stubs(:terminus_type=)
      Oregano::Indirector::Memory.inherited(subclass)
    end

    it "should convert the indirection name to a downcased symbol" do
      subclass.expects(:indirection=).with(:test_ind)
      subclass.stubs(:name=)
      subclass.stubs(:terminus_type=)
      Oregano::Indirector::Memory.inherited(subclass)
    end

    it "should convert camel case to lower case with underscores as word separators" do
      subclass.expects(:name=).with(:one_two)
      subclass.stubs(:indirection=)

      Oregano::Indirector::Terminus.inherited(subclass)
    end
  end

  describe "when creating terminus class types" do
    before :all do
      Oregano::Indirector::Terminus.stubs(:register_terminus_class)

      class Oregano::Indirector::Terminus::TestTerminusType < Oregano::Indirector::Terminus
      end
    end

    after :all do
      Oregano::Indirector::Terminus.send(:remove_const, :TestTerminusType)
    end

    let :subclass do
      Oregano::Indirector::Terminus::TestTerminusType
    end

    it "should set the name of the abstract subclass to be its class constant" do
      expect(subclass.name).to eq(:test_terminus_type)
    end

    it "should mark abstract terminus types as such" do
      expect(subclass).to be_abstract_terminus
    end

    it "should not allow instances of abstract subclasses to be created" do
      expect { subclass.new }.to raise_error(Oregano::DevError)
    end
  end

  describe "when listing terminus classes" do
    it "should list the terminus files available to load" do
      Oregano::Util::Autoload.any_instance.stubs(:files_to_load).returns ["/foo/bar/baz", "/max/runs/marathon"]
      expect(Oregano::Indirector::Terminus.terminus_classes('my_stuff')).to eq([:baz, :marathon])
    end
  end

  describe "when validating a request" do
    let :request do
      Oregano::Indirector::Request.new(indirection.name, :find, "the_key", instance)
    end

    describe "`instance.name` does not match the key in the request" do
      let(:instance) { model.new("wrong_key") }

      it "raises an error " do
        expect {
          terminus.validate(request)
        }.to raise_error(
          Oregano::Indirector::ValidationError,
          /Instance name .* does not match requested key/
        )
      end
    end

    describe "`instance` is not an instance of the model class" do
      let(:instance) { mock "instance" }

      it "raises an error" do
        expect {
          terminus.validate(request)
        }.to raise_error(
          Oregano::Indirector::ValidationError,
          /Invalid instance type/
        )
      end
    end

    describe "the instance key and class match the request key and model class" do
      let(:instance) { model.new("the_key") }

      it "passes" do
        terminus.validate(request)
      end
    end
  end
end
