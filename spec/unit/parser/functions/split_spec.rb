#! /usr/bin/env ruby
require 'spec_helper'

describe "the split function" do
  before :all do
    Oregano::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Oregano::Node.new('localhost')
    compiler = Oregano::Parser::Compiler.new(node)
    @scope   = Oregano::Parser::Scope.new(compiler)
  end

  it 'should raise a ParseError' do
    expect { @scope.function_split([ '130;236;254;10', ';']) }.to raise_error(Oregano::ParseError, /can only be called using the 4.x function API/)
  end
end
