#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/node/memory'

require 'shared_behaviours/memory_terminus'

describe Oregano::Node::Memory do
  before do
    @name = "me"
    @searcher = Oregano::Node::Memory.new
    @instance = stub 'instance', :name => @name

    @request = stub 'request', :key => @name, :instance => @instance
  end

  it_should_behave_like "A Memory Terminus"
end
