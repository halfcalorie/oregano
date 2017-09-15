#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/file_serving/mount'

describe Oregano::FileServing::Mount do
  it "should use 'mount[$name]' as its string form" do
    expect(Oregano::FileServing::Mount.new("foo").to_s).to eq("mount[foo]")
  end
end

describe Oregano::FileServing::Mount, " when initializing" do
  it "should fail on non-alphanumeric name" do
    expect { Oregano::FileServing::Mount.new("non alpha") }.to raise_error(ArgumentError)
  end

  it "should allow dashes in its name" do
    expect(Oregano::FileServing::Mount.new("non-alpha").name).to eq("non-alpha")
  end
end

describe Oregano::FileServing::Mount, " when finding files" do
  it "should fail" do
    expect { Oregano::FileServing::Mount.new("test").find("foo", :one => "two") }.to raise_error(NotImplementedError)
  end
end

describe Oregano::FileServing::Mount, " when searching for files" do
  it "should fail" do
    expect { Oregano::FileServing::Mount.new("test").search("foo", :one => "two") }.to raise_error(NotImplementedError)
  end
end
