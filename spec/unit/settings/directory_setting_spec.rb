#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/settings'
require 'oregano/settings/directory_setting'

describe Oregano::Settings::DirectorySetting do
  DirectorySetting = Oregano::Settings::DirectorySetting

  include OreganoSpec::Files

  before do
    @basepath = make_absolute("/somepath")
  end

  describe "when being converted to a resource" do
    before do
      @settings = mock 'settings'
      @dir = Oregano::Settings::DirectorySetting.new(
          :settings => @settings, :desc => "eh", :name => :mydir, :section => "mysect")
      @settings.stubs(:value).with(:mydir).returns @basepath
    end

    it "should return :directory as its type" do
      expect(@dir.type).to eq(:directory)
    end



  end
end

