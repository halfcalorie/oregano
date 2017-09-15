#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/util/splayer'

describe Oregano::Util::Splayer do
  include Oregano::Util::Splayer

  let (:subject) { self }

  before do
    Oregano[:splay] = true
    Oregano[:splaylimit] = "10"
  end

  it "should do nothing if splay is disabled" do
    Oregano[:splay] = false
    subject.expects(:sleep).never
    subject.splay
  end

  it "should do nothing if it has already splayed" do
    subject.expects(:splayed?).returns true
    subject.expects(:sleep).never
    subject.splay
  end

  it "should log that it is splaying" do
    subject.stubs :sleep
    Oregano.expects :info
    subject.splay
  end

  it "should sleep for a random portion of the splaylimit plus 1" do
    Oregano[:splaylimit] = "50"
    subject.expects(:rand).with(51).returns 10
    subject.expects(:sleep).with(10)
    subject.splay
  end

  it "should mark that it has splayed" do
    subject.stubs(:sleep)
    subject.splay
    expect(subject).to be_splayed
  end
end
