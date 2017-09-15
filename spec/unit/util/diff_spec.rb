#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/util/diff'
require 'oregano/util/execution'

describe Oregano::Util::Diff do
  describe ".diff" do
    it "should execute the diff command with arguments" do
      Oregano[:diff] = 'foo'
      Oregano[:diff_args] = 'bar'

      Oregano::Util::Execution.expects(:execute).with(['foo', 'bar', 'a', 'b'], {:failonfail => false, :combine => false}).returns('baz')
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should execute the diff command with multiple arguments" do
      Oregano[:diff] = 'foo'
      Oregano[:diff_args] = 'bar qux'

      Oregano::Util::Execution.expects(:execute).with(['foo', 'bar', 'qux', 'a', 'b'], anything).returns('baz')
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should omit diff arguments if none are specified" do
      Oregano[:diff] = 'foo'
      Oregano[:diff_args] = ''

      Oregano::Util::Execution.expects(:execute).with(['foo', 'a', 'b'], {:failonfail => false, :combine => false}).returns('baz')
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should return empty string if the diff command is empty" do
      Oregano[:diff] = ''

      Oregano::Util::Execution.expects(:execute).never
      expect(subject.diff('a', 'b')).to eq('')
    end
  end
end
