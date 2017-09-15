#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'tag' function" do
  before :all do
    Oregano::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Oregano::Node.new('localhost')
    compiler = Oregano::Parser::Compiler.new(node)
    @scope   = Oregano::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Oregano::Parser::Functions.function(:tag)).to eq("function_tag")
  end

  it "should tag the resource with any provided tags" do
    resource = Oregano::Parser::Resource.new(:file, "/file", :scope => @scope)
    @scope.expects(:resource).returns resource

    @scope.function_tag ["one", "two"]

    expect(resource).to be_tagged("one")
    expect(resource).to be_tagged("two")
  end
end
