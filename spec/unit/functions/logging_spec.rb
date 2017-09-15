require 'spec_helper'
require 'oregano_spec/compiler'

describe 'the log function' do
  include OreganoSpec::Compiler

  def collect_logs(code)
    Oregano[:code] = code
    node = Oregano::Node.new('logtest')
    compiler = Oregano::Parser::Compiler.new(node)
    node.environment.check_for_reparse
    logs = []
    Oregano::Util::Log.with_destination(Oregano::Test::LogCollector.new(logs)) do
      compiler.compile
    end
    logs
  end

  def expect_log(code, log_level, message)
    logs = collect_logs(code)
    expect(logs.size).to eql(1)
    expect(logs[0].level).to eql(log_level)
    expect(logs[0].message).to eql(message)
  end

  before(:each) do
    Oregano[:log_level] = 'debug'
  end

  Oregano::Util::Log.levels.each do |level|
    context "for log level '#{level}'" do
      it 'can be called' do
        expect_log("#{level.to_s}('yay')", level, 'yay')
      end

      it 'joins multiple arguments using space' do
        # Not using the evaluator would result in yay {"a"=>"b", "c"=>"d"}
        expect_log("#{level.to_s}('a', 'b', 3)", level, 'a b 3')
      end

      it 'uses the evaluator to format output' do
        # Not using the evaluator would result in yay {"a"=>"b", "c"=>"d"}
        expect_log("#{level.to_s}('yay', {a => b, c => d})", level, 'yay {a => b, c => d}')
      end

      it 'returns undef value' do
        logs = collect_logs("notice(type(#{level.to_s}('yay')))")
        expect(logs.size).to eql(2)
        expect(logs[1].level).to eql(:notice)
        expect(logs[1].message).to eql('Undef')
      end
    end
  end
end
