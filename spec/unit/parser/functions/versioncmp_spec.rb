#! /usr/bin/env ruby
require 'spec_helper'

describe "the versioncmp function" do
  before :all do
    Oregano::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Oregano::Node.new('localhost')
    compiler = Oregano::Parser::Compiler.new(node)
    @scope   = Oregano::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Oregano::Parser::Functions.function("versioncmp")).to eq("function_versioncmp")
  end

  it "should raise an ArgumentError if there is less than 2 arguments" do
    expect { @scope.function_versioncmp(["1.2"]) }.to raise_error(ArgumentError)
  end

  it "should raise an ArgumentError if there is more than 2 arguments" do
    expect { @scope.function_versioncmp(["1.2", "2.4.5", "3.5.6"]) }.to raise_error(ArgumentError)
  end

  it "should call Oregano::Util::Package.versioncmp (included in scope)" do
    Oregano::Util::Package.expects(:versioncmp).with("1.2", "1.3").returns(-1)

    @scope.function_versioncmp(["1.2", "1.3"])
  end

end
