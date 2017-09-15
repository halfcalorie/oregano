#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/transaction/report'
require 'oregano/indirector/report/yaml'

describe Oregano::Transaction::Report::Yaml do
  it "should be a subclass of the Yaml terminus" do
    expect(Oregano::Transaction::Report::Yaml.superclass).to equal(Oregano::Indirector::Yaml)
  end

  it "should have documentation" do
    expect(Oregano::Transaction::Report::Yaml.doc).not_to be_nil
  end

  it "should be registered with the report indirection" do
    indirection = Oregano::Indirector::Indirection.instance(:report)
    expect(Oregano::Transaction::Report::Yaml.indirection).to equal(indirection)
  end

  it "should have its name set to :yaml" do
    expect(Oregano::Transaction::Report::Yaml.name).to eq(:yaml)
  end

  it "should unconditionally save/load from the --lastrunreport setting" do
    expect(subject.path(:me)).to eq(Oregano[:lastrunreport])
  end
end
