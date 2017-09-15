#! /usr/bin/env ruby
require 'spec_helper'

describe "the regsubst function" do
  before :all do
    Oregano::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Oregano::Node.new('localhost')
    compiler = Oregano::Parser::Compiler.new(node)
    @scope   = Oregano::Parser::Scope.new(compiler)
  end

  it 'should raise an ParseError' do
    expect do
      @scope.function_regsubst(
      [ 'the monkey breaks banana trees',
        'b[an]*a',
        'coconut'
      ])
    end.to raise_error(Oregano::ParseError, /can only be called using the 4.x function API/)
  end
end
