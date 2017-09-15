#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/indirector/memory'

require 'shared_behaviours/memory_terminus'

describe Oregano::Indirector::Memory do
  it_should_behave_like "A Memory Terminus"

  before do
    Oregano::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Oregano::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @memory_class = class Testing::MyMemory < Oregano::Indirector::Memory
      self
    end

    @searcher = @memory_class.new
    @name = "me"
    @instance = stub 'instance', :name => @name

    @request = stub 'request', :key => @name, :instance => @instance
  end
end
