#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/indirector/code'

describe Oregano::Indirector::Code do
  before :all do
    Oregano::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Oregano::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @code_class = class Testing::MyCode < Oregano::Indirector::Code
      self
    end

    @searcher = @code_class.new
  end

  it "should not have a find() method defined" do
    expect(@searcher).not_to respond_to(:find)
  end

  it "should not have a save() method defined" do
    expect(@searcher).not_to respond_to(:save)
  end

  it "should not have a destroy() method defined" do
    expect(@searcher).not_to respond_to(:destroy)
  end
end
