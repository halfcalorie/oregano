#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/transaction/report'
require 'oregano/indirector/report/msgpack'

describe Oregano::Transaction::Report::Msgpack, :if => Oregano.features.msgpack? do
  it "should be a subclass of the Msgpack terminus" do
    expect(Oregano::Transaction::Report::Msgpack.superclass).to equal(Oregano::Indirector::Msgpack)
  end

  it "should have documentation" do
    expect(Oregano::Transaction::Report::Msgpack.doc).not_to be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:report)
    expect(Oregano::Transaction::Report::Msgpack.indirection).to equal(indirection)
  end

  it "should have its name set to :msgpack" do
    expect(Oregano::Transaction::Report::Msgpack.name).to eq(:msgpack)
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    expect(subject.path(:me)).to eq(Oregano[:lastrunreport])
  end
end
