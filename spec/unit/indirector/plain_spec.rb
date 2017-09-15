#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/indirector/plain'

describe Oregano::Indirector::Plain do
  before do
    Oregano::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Oregano::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @plain_class = class Testing::MyPlain < Oregano::Indirector::Plain
      self
    end

    @searcher = @plain_class.new

    @request = stub 'request', :key => "yay"
  end

  it "should return return an instance of the indirected model" do
    object = mock 'object'
    @model.expects(:new).with(@request.key).returns object
    expect(@searcher.find(@request)).to equal(object)
  end
end
