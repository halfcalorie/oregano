#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Resource::Catalog do
  describe "when using the indirector" do
    before do
      # This is so the tests work w/out networking.
      Facter.stubs(:to_hash).returns({"hostname" => "foo.domain.com"})
      Facter.stubs(:value).returns("eh")
    end


    it "should be able to delegate to the :yaml terminus" do
      Oregano::Resource::Catalog.indirection.stubs(:terminus_class).returns :yaml

      # Load now, before we stub the exists? method.
      terminus = Oregano::Resource::Catalog.indirection.terminus(:yaml)
      terminus.expects(:path).with("me").returns "/my/yaml/file"

      Oregano::FileSystem.expects(:exist?).with("/my/yaml/file").returns false
      expect(Oregano::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should be able to delegate to the :compiler terminus" do
      Oregano::Resource::Catalog.indirection.stubs(:terminus_class).returns :compiler

      # Load now, before we stub the exists? method.
      compiler = Oregano::Resource::Catalog.indirection.terminus(:compiler)

      node = mock 'node'
      node.stub_everything

      Oregano::Node.indirection.expects(:find).returns(node)
      compiler.expects(:compile).with(node, anything).returns nil

      expect(Oregano::Resource::Catalog.indirection.find("me")).to be_nil
    end

    it "should pass provided node information directly to the terminus" do
      terminus = mock 'terminus'

      Oregano::Resource::Catalog.indirection.stubs(:terminus).returns terminus

      node = mock 'node'
      terminus.stubs(:validate)
      terminus.expects(:find).with { |request| request.options[:use_node] == node }
      Oregano::Resource::Catalog.indirection.find("me", :use_node => node)
    end
  end
end
