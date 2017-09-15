#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/node'
require 'oregano/indirector/node/write_only_yaml'

describe Oregano::Node::WriteOnlyYaml do
  it "should be deprecated" do
    Oregano.expects(:warn_once).with('deprecations', 'Oregano::Node::WriteOnlyYaml', 'Oregano::Node::WriteOnlyYaml is deprecated and will be removed in a future release of Oregano.')
    described_class.new
  end
end
