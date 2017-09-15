#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano_spec/files'
require 'oregano/application/doc'

describe Oregano::Application::Doc do
  include OreganoSpec::Files

  it "should respect the -o option" do
    oreganodoc = Oregano::Application[:doc]
    oreganodoc.command_line.stubs(:args).returns(['foo', '-o', 'bar'])
    oreganodoc.parse_options
    expect(oreganodoc.options[:outputdir]).to eq('bar')
  end
end
