#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/application/config'

describe Oregano::Application::Config do
  it "should be a subclass of Oregano::Application::FaceBase" do
    expect(Oregano::Application::Config.superclass).to equal(Oregano::Application::FaceBase)
  end
end
