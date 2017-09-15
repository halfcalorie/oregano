#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'fail' parser function" do
  before :all do
    Oregano::Parser::Functions.autoloader.loadall
  end

  let :scope do
    node     = Oregano::Node.new('localhost')
    compiler = Oregano::Parser::Compiler.new(node)
    scope    = Oregano::Parser::Scope.new(compiler)
    scope.stubs(:environment).returns(nil)
    scope
  end

  it "should exist" do
    expect(Oregano::Parser::Functions.function(:fail)).to eq("function_fail")
  end

  it "should raise a parse error if invoked" do
    expect { scope.function_fail([]) }.to raise_error Oregano::ParseError
  end

  it "should join arguments into a string in the error" do
    expect { scope.function_fail(["hello", "world"]) }.to raise_error /hello world/
  end
end
