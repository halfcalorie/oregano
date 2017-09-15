#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/application/facts'

describe Oregano::Application::Facts do
  before :each do
    subject.command_line.stubs(:subcommand_name).returns 'facts'
  end

  it "should return facts if a key is given to find" do
    Oregano::Node::Facts.indirection.reset_terminus_class
    Oregano::Node::Facts.indirection.expects(:find).returns(Oregano::Node::Facts.new('whatever', {}))
    subject.command_line.stubs(:args).returns %w{find whatever --render-as yaml}

    expect {
      expect {
        subject.run
      }.to exit_with(0)
    }.to have_printed(/object:Oregano::Node::Facts/)

    expect(@logs).to be_empty
  end
end
