#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/status/local'

describe Oregano::Indirector::Status::Local do
  it "should set the oregano version" do
    Oregano::Status.indirection.terminus_class = :local
    expect(Oregano::Status.indirection.find('*').version).to eq(Oregano.version)
  end
end
