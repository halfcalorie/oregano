require 'spec_helper'
require 'oregano/provider/aixobject'

describe Oregano::Provider::AixObject do
  let(:resource) do
    Oregano::Type.type(:user).new(
      :name   => 'test_aix_user',
      :ensure => :present
    )
  end

  let(:provider) do
    provider = Oregano::Provider::AixObject.new resource
  end

  describe "base provider methods" do
    [ :lscmd,
      :addcmd,
      :modifycmd,
      :deletecmd
    ].each do |method|
      it "should raise an error when unimplemented method #{method} called" do
        expect do
          provider.send(method)
        end.to raise_error(Oregano::Error, /not defined/)
      end
    end
  end

  describe "attribute mapping methods" do
    let(:mapping) do
      [
        { :aix_attr => :test_aix_property,
          :oregano_prop => :test_oregano_property,
          :to => :test_convert_to_aix_method,
          :from => :test_convert_to_oregano_method
        }
      ]
    end

    before(:each) do
      provider.class.attribute_mapping = mapping
    end

    describe ".attribute_mapping_to" do
      before(:each) do
         if provider.class.instance_variable_defined? :@attribute_mapping_to
           provider.class.send(:remove_instance_variable, :@attribute_mapping_to)
         end
      end

      it "should create a hash where the key is the oregano property and the value is a hash with the aix property and the conversion method" do
        hash = provider.class.attribute_mapping_to
        expect(hash).to have_key :test_oregano_property
        sub_hash = hash[:test_oregano_property]
        expect(sub_hash).to have_key :key
        expect(sub_hash).to have_key :method
        expect(sub_hash[:key]).to eq(:test_aix_property)
        expect(sub_hash[:method]).to eq(:test_convert_to_aix_method)
      end

      it "should cache results between calls" do
        provider.class.expects(:attribute_mapping).returns(mapping).once
        provider.class.attribute_mapping_to
        provider.class.attribute_mapping_to
      end
    end

    describe ".attribute_mapping_from" do
      before(:each) do
        if provider.class.instance_variable_defined? :@attribute_mapping_from
          provider.class.send(:remove_instance_variable, :@attribute_mapping_from)
        end
      end

      it "should create a hash where the key is the aix property and the value is a hash with the oregano property and the conversion method" do
        hash = provider.class.attribute_mapping_from
        expect(hash).to have_key :test_aix_property
        sub_hash = hash[:test_aix_property]
        expect(sub_hash).to have_key :key
        expect(sub_hash).to have_key :method
        expect(sub_hash[:key]).to eq(:test_oregano_property)
        expect(sub_hash[:method]).to eq(:test_convert_to_oregano_method)
      end

      it "should cache results between calls" do
        provider.class.expects(:attribute_mapping).returns(mapping).once
        provider.class.attribute_mapping_from
        provider.class.attribute_mapping_from
      end
    end
  end

  describe "#getinfo" do
    it "should only execute the system command once" do
      provider.stubs(:lscmd).returns "ls"
      provider.expects(:execute).returns("bob=frank").once
      provider.getinfo(true)
    end
  end
end