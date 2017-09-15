#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Util::ExecutionStub do
  it "should use the provided stub code when 'set' is called" do
    Oregano::Util::ExecutionStub.set do |command, options|
      expect(command).to eq(['/bin/foo', 'bar'])
      "stub output"
    end
    expect(Oregano::Util::ExecutionStub.current_value).not_to eq(nil)
    expect(Oregano::Util::Execution.execute(['/bin/foo', 'bar'])).to eq("stub output")
  end

  it "should automatically restore normal execution at the conclusion of each spec test" do
    # Note: this test relies on the previous test creating a stub.
    expect(Oregano::Util::ExecutionStub.current_value).to eq(nil)
  end

  it "should restore normal execution after 'reset' is called" do
    # Note: "true" exists at different paths in different OSes
    if Oregano.features.microsoft_windows?
      true_command = [Oregano::Util.which('cmd.exe').tr('/', '\\'), '/c', 'exit 0']
    else
      true_command = [Oregano::Util.which('true')]
    end
    stub_call_count = 0
    Oregano::Util::ExecutionStub.set do |command, options|
      expect(command).to eq(true_command)
      stub_call_count += 1
      'stub called'
    end
    expect(Oregano::Util::Execution.execute(true_command)).to eq('stub called')
    expect(stub_call_count).to eq(1)
    Oregano::Util::ExecutionStub.reset
    expect(Oregano::Util::ExecutionStub.current_value).to eq(nil)
    expect(Oregano::Util::Execution.execute(true_command)).to eq('')
    expect(stub_call_count).to eq(1)
  end
end
