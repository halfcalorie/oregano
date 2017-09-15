#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Node::Facts do
  describe "when using the indirector" do
    it "should expire any cached node instances when it is saved" do
      Oregano::Node::Facts.indirection.stubs(:terminus_class).returns :yaml

      expect(Oregano::Node::Facts.indirection.terminus(:yaml)).to equal(Oregano::Node::Facts.indirection.terminus(:yaml))
      terminus = Oregano::Node::Facts.indirection.terminus(:yaml)
      terminus.stubs :save

      Oregano::Node.indirection.expects(:expire).with("me", optionally(instance_of(Hash)))

      facts = Oregano::Node::Facts.new("me")
      Oregano::Node::Facts.indirection.save(facts)
    end

    it "should be able to delegate to the :yaml terminus" do
      Oregano::Node::Facts.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Oregano::Node::Facts.indirection.terminus(:yaml)

      terminus.expects(:path).with("me").returns "/my/yaml/file"
      Oregano::FileSystem.expects(:exist?).with("/my/yaml/file").returns false

      expect(Oregano::Node::Facts.indirection.find("me")).to be_nil
    end

    it "should be able to delegate to the :facter terminus" do
      Oregano::Node::Facts.indirection.stubs(:terminus_class).returns :facter

      Facter.expects(:to_hash).returns "facter_hash"
      facts = Oregano::Node::Facts.new("me")
      Oregano::Node::Facts.expects(:new).with("me", "facter_hash").returns facts

      expect(Oregano::Node::Facts.indirection.find("me")).to equal(facts)
    end
  end
end
