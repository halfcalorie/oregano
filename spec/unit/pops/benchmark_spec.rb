#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/pops'
require 'oregano_spec/pops'
require 'oregano_spec/scope'

describe "Benchmark", :benchmark => true do
  include OreganoSpec::Pops
  include OreganoSpec::Scope

    def code
      'if true
{
$a = 10 + 10
}
else
{
$a = "interpolate ${foo} and stuff"
}
'    end

  class StringWriter < String
    alias write concat
  end

  def json_dump(model)
    output = StringWriter.new
    ser = Oregano::Pops::Serialization::Serializer.new(Oregano::Pops::Serialization::JSON.writer.new(output))
    ser.write(model)
    ser.finish
    output
  end

  it "transformer", :profile => true do
    parser = Oregano::Pops::Parser::Parser.new()
    model = parser.parse_string(code).model
    transformer = Oregano::Pops::Model::AstTransformer.new()
    m = Benchmark.measure { 10000.times { transformer.transform(model) }}
    puts "Transformer: #{m}"
  end

  it "validator", :profile => true do
    parser = Oregano::Pops::Parser::EvaluatingParser.new()
    model = parser.parse_string(code)
    m = Benchmark.measure { 100000.times { parser.assert_and_report(model) }}
    puts "Validator: #{m}"
  end

  it "parse transform", :profile => true do
    parser = Oregano::Pops::Parser::Parser.new()
    transformer = Oregano::Pops::Model::AstTransformer.new()
    m = Benchmark.measure { 10000.times { transformer.transform(parser.parse_string(code).model) }}
    puts "Parse and transform: #{m}"
  end

  it "parser0", :profile => true do
    parser = Oregano::Parser::Parser.new('test')
    m = Benchmark.measure { 10000.times { parser.parse(code) }}
    puts "Parser 0: #{m}"
  end

  it "parser1", :profile => true do
    parser = Oregano::Pops::Parser::EvaluatingParser.new()
    m = Benchmark.measure { 10000.times { parser.parse_string(code) }}
    puts "Parser1: #{m}"
  end

  it "marshal1", :profile => true do
    parser = Oregano::Pops::Parser::EvaluatingParser.new()
    model = parser.parse_string(code).model
    dumped = Marshal.dump(model)
    m = Benchmark.measure { 10000.times { Marshal.load(dumped) }}
    puts "Marshal1: #{m}"
  end

  it "rgenjson", :profile => true do
    parser = Oregano::Pops::Parser::EvaluatingParser.new()
    model = parser.parse_string(code).model
    dumped = json_dump(model)
    m = Benchmark.measure { 10000.times { json_load(dumped) }}
    puts "Pcore Json: #{m}"
  end

  it "lexer2", :profile => true do
    lexer = Oregano::Pops::Parser::Lexer2.new
     m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
     puts "Lexer2: #{m}"
  end

  it "lexer1", :profile => true do
    lexer = Oregano::Pops::Parser::Lexer.new
    m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
    puts "Pops Lexer: #{m}"
  end

  it "lexer0", :profile => true do
    lexer = Oregano::Parser::Lexer.new
    m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
    puts "Original Lexer: #{m}"
  end

  context "Measure Evaluator" do
    let(:parser) { Oregano::Pops::Parser::EvaluatingParser.new }
    let(:node) { 'node.example.com' }
    let(:scope) { s = create_test_scope_for_node(node); s }
    it "evaluator", :profile => true do
      # Do the loop in oregano code since it otherwise drowns in setup
      oregano_loop =
        'Integer[0, 1000].each |$i| { if true
{
$a = 10 + 10
}
else
{
$a = "interpolate ${foo} and stuff"
}}
'
      # parse once, only measure the evaluation
      model = parser.parse_string(oregano_loop, __FILE__)
      m = Benchmark.measure { parser.evaluate(create_test_scope_for_node(node), model) }
      puts("Evaluator: #{m}")
    end
  end
end
