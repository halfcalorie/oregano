#!/usr/bin/env ruby
require 'spec_helper'

require 'oregano/settings'
require 'oregano/settings/priority_setting'
require 'oregano/util/platform'

describe Oregano::Settings::PrioritySetting do
  let(:setting) { described_class.new(:settings => mock('settings'), :desc => "test") }

  it "is of type :priority" do
    expect(setting.type).to eq(:priority)
  end

  describe "when munging the setting" do
    it "passes nil through" do
      expect(setting.munge(nil)).to be_nil
    end

    it "returns the same value if given an integer" do
      expect(setting.munge(5)).to eq(5)
    end

    it "returns an integer if given a decimal string" do
      expect(setting.munge('12')).to eq(12)
    end

    it "returns a negative integer if given a negative integer string" do
      expect(setting.munge('-5')).to eq(-5)
    end

    it "fails if given anything else" do
      [ 'foo', 'realtime', true, 8.3, [] ].each do |value|
        expect {
          setting.munge(value)
        }.to raise_error(Oregano::Settings::ValidationError)
      end
    end

    describe "on a Unix-like platform it", :unless => Oregano::Util::Platform.windows? do
      it "parses high, normal, low, and idle priorities" do
        {
          'high'   => -10,
          'normal' => 0,
          'low'    => 10,
          'idle'   => 19
        }.each do |value, converted_value|
          expect(setting.munge(value)).to eq(converted_value)
        end
      end
    end

    describe "on a Windows-like platform it", :if => Oregano::Util::Platform.windows? do
      it "parses high, normal, low, and idle priorities" do
        {
          'high'   => Oregano::Util::Windows::Process::HIGH_PRIORITY_CLASS,
          'normal' => Oregano::Util::Windows::Process::NORMAL_PRIORITY_CLASS,
          'low'    => Oregano::Util::Windows::Process::BELOW_NORMAL_PRIORITY_CLASS,
          'idle'   => Oregano::Util::Windows::Process::IDLE_PRIORITY_CLASS
        }.each do |value, converted_value|
          expect(setting.munge(value)).to eq(converted_value)
        end
      end
    end
  end
end
