#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/node'

describe Oregano::Node do
  describe "when delegating indirection calls" do
    before do
      Oregano::Node.indirection.reset_terminus_class
      Oregano::Node.indirection.cache_class = nil

      @name = "me"
      @node = Oregano::Node.new(@name)
    end

    it "should be able to use the yaml terminus" do
      Oregano::Node.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Oregano::Node.indirection.terminus(:yaml)

      terminus.expects(:path).with(@name).returns "/my/yaml/file"

      Oregano::FileSystem.expects(:exist?).with("/my/yaml/file").returns false
      expect(Oregano::Node.indirection.find(@name)).to be_nil
    end

    it "should have an ldap terminus" do
      expect(Oregano::Node.indirection.terminus(:ldap)).not_to be_nil
    end

    it "should be able to use the plain terminus" do
      Oregano::Node.indirection.stubs(:terminus_class).returns :plain

      # Load now, before we stub the exists? method.
      Oregano::Node.indirection.terminus(:plain)

      Oregano::Node.expects(:new).with(@name).returns @node

      expect(Oregano::Node.indirection.find(@name)).to equal(@node)
    end

    describe "and using the memory terminus" do
      before do
        @name = "me"
        @terminus = Oregano::Node.indirection.terminus(:memory)
        Oregano::Node.indirection.stubs(:terminus).returns @terminus
        @node = Oregano::Node.new(@name)
      end

      after do
        @terminus.instance_variable_set(:@instances, {})
      end

      it "should find no nodes by default" do
        expect(Oregano::Node.indirection.find(@name)).to be_nil
      end

      it "should be able to find nodes that were previously saved" do
        Oregano::Node.indirection.save(@node)
        expect(Oregano::Node.indirection.find(@name)).to equal(@node)
      end

      it "should replace existing saved nodes when a new node with the same name is saved" do
        Oregano::Node.indirection.save(@node)
        two = Oregano::Node.new(@name)
        Oregano::Node.indirection.save(two)
        expect(Oregano::Node.indirection.find(@name)).to equal(two)
      end

      it "should be able to remove previously saved nodes" do
        Oregano::Node.indirection.save(@node)
        Oregano::Node.indirection.destroy(@node.name)
        expect(Oregano::Node.indirection.find(@name)).to be_nil
      end

      it "should fail when asked to destroy a node that does not exist" do
        expect { Oregano::Node.indirection.destroy(@node) }.to raise_error(ArgumentError)
      end
    end
  end
end
