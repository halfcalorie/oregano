#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/util/json_lockfile'

describe Oregano::Util::JsonLockfile do
  require 'oregano_spec/files'
  include OreganoSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Oregano::Util::JsonLockfile.new(@lockfile)
  end

  describe "#lock" do
    it "should create a lock file containing a json hash" do
      data = { "foo" => "foofoo", "bar" => "barbar" }
      @lock.lock(data)

      expect(PSON.parse(File.read(@lockfile))).to eq(data)
    end
  end

  describe "reading lock data" do
    it "returns deserialized JSON from the lockfile" do
      data = { "foo" => "foofoo", "bar" => "barbar" }
      @lock.lock(data)
      expect(@lock.lock_data).to eq data
    end

    it "returns nil if the file read returned nil" do
      @lock.lock
      File.stubs(:read).returns nil
      expect(@lock.lock_data).to be_nil
    end

    it "returns nil if the file was empty" do
      @lock.lock
      File.stubs(:read).returns ''
      expect(@lock.lock_data).to be_nil
    end

    it "returns nil if the file was not in PSON" do
      @lock.lock
      File.stubs(:read).returns ']['
      expect(@lock.lock_data).to be_nil
    end

  end
end
