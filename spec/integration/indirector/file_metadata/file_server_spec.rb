#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_metadata/file_server'
require 'shared_behaviours/file_server_terminus'

require 'oregano_spec/files'

describe Oregano::Indirector::FileMetadata::FileServer, " when finding files" do
  it_should_behave_like "Oregano::Indirector::FileServerTerminus"
  include OreganoSpec::Files
  include_context 'with supported checksum types'

  before do
    @terminus = Oregano::Indirector::FileMetadata::FileServer.new
    @test_class = Oregano::FileServing::Metadata
    Oregano::FileServing::Configuration.instance_variable_set(:@configuration, nil)
  end

  describe "with a plugin environment specified in the request" do
    with_checksum_types("file_content_with_env", "mod/lib/file.rb") do
      it "should return the correct metadata" do
        Oregano.settings[:modulepath] = "/no/such/file"
        env = Oregano::Node::Environment.create(:foo, [env_path])
        result = Oregano::FileServing::Metadata.indirection.search("plugins", :environment => env, :checksum_type => checksum_type, :recurse => true)

        expect(result).to_not be_nil
        expect(result.length).to eq(2)
        result.map {|x| expect(x).to be_instance_of(Oregano::FileServing::Metadata)}
        expect_correct_checksum(result.find {|x| x.relative_path == 'file.rb'}, checksum_type, checksum, Oregano::FileServing::Metadata)
      end
    end
  end

  describe "in modules" do
    with_checksum_types("file_content", "mymod/files/myfile") do
      it "should return the correct metadata" do
        env = Oregano::Node::Environment.create(:foo, [env_path])
        result = Oregano::FileServing::Metadata.indirection.find("modules/mymod/myfile", :environment => env, :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Oregano::FileServing::Metadata)
      end
    end
  end

  describe "that are tasks in modules" do
    with_checksum_types("task_file_content", "mymod/tasks/mytask") do
      it "should return the correct metadata" do
        env = Oregano::Node::Environment.create(:foo, [env_path])
        result = Oregano::FileServing::Metadata.indirection.find("tasks/mymod/mytask", :environment => env, :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Oregano::FileServing::Metadata)
      end
    end
  end

  describe "when node name expansions are used" do
    with_checksum_types("file_server_testing", "mynode/myfile") do
      it "should return the correct metadata" do
        Oregano::FileSystem.stubs(:exist?).with(checksum_file).returns true
        Oregano::FileSystem.stubs(:exist?).with(Oregano[:fileserverconfig]).returns(true)

        # Use a real mount, so the integration is a bit deeper.
        mount1 = Oregano::FileServing::Configuration::Mount::File.new("one")
        mount1.stubs(:globalallow?).returns true
        mount1.stubs(:allowed?).returns true
        mount1.path = File.join(env_path, "%h")

        parser = stub 'parser', :changed? => false
        parser.stubs(:parse).returns("one" => mount1)

        Oregano::FileServing::Configuration::Parser.stubs(:new).returns(parser)
        env = Oregano::Node::Environment.create(:foo, [])

        result = Oregano::FileServing::Metadata.indirection.find("one/myfile", :environment => env, :node => "mynode", :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Oregano::FileServing::Metadata)
      end
    end
  end
end
