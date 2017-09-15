#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:facts, '0.0.1'] do
  describe "#find" do
    it { is_expected.to be_action :find }
  end
end
