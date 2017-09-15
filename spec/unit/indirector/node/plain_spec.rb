#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/node/plain'

describe Oregano::Node::Plain do
  let(:nodename) { "mynode" }
  let(:indirection_fact_values) { {:afact => "a value"} }
  let(:indirection_facts) { Oregano::Node::Facts.new(nodename, indirection_fact_values) }
  let(:request_fact_values) { {:foo => "bar" } }
  let(:request_facts) { Oregano::Node::Facts.new(nodename, request_fact_values)}
  let(:environment) { Oregano::Node::Environment.create(:myenv, []) }
  let(:request) { Oregano::Indirector::Request.new(:node, :find, nodename, nil, :environment => environment) }
  let(:node_indirection) { Oregano::Node::Plain.new }

  it "should merge facts from the request if supplied" do
    Oregano::Node::Facts.indirection.expects(:find).never
    request.options[:facts] = request_facts
    node = node_indirection.find(request)
    expect(node.parameters).to include(request_fact_values)
    expect(node.facts).to eq(request_facts)
  end

  it "should find facts if none are supplied" do
    Oregano::Node::Facts.indirection.expects(:find).with(nodename, :environment => environment).returns(indirection_facts)
    request.options.delete(:facts)
    node = node_indirection.find(request)
    expect(node.parameters).to include(indirection_fact_values)
    expect(node.facts).to eq(indirection_facts)
  end

  it "should set the node environment from the request" do
    expect(node_indirection.find(request).environment).to eq(environment)
  end

end
