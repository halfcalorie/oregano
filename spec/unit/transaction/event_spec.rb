#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/transaction/event'

class TestResource
  def to_s
    "Foo[bar]"
  end
  def [](v)
    nil
  end
end

describe Oregano::Transaction::Event do
  include OreganoSpec::Files

  it "should support resource" do
    event = Oregano::Transaction::Event.new
    event.resource = TestResource.new
    expect(event.resource).to eq("Foo[bar]")
  end

  it "should always convert the property to a string" do
    expect(Oregano::Transaction::Event.new(:property => :foo).property).to eq("foo")
  end

  it "should always convert the resource to a string" do
    expect(Oregano::Transaction::Event.new(:resource => TestResource.new).resource).to eq("Foo[bar]")
  end

  it "should produce the message when converted to a string" do
    event = Oregano::Transaction::Event.new
    event.expects(:message).returns "my message"
    expect(event.to_s).to eq("my message")
  end

  it "should support 'status'" do
    event = Oregano::Transaction::Event.new
    event.status = "success"
    expect(event.status).to eq("success")
  end

  it "should fail if the status is not to 'audit', 'noop', 'success', or 'failure" do
    event = Oregano::Transaction::Event.new
    expect { event.status = "foo" }.to raise_error(ArgumentError)
  end

  it "should support tags" do
    expect(Oregano::Transaction::Event.ancestors).to include(Oregano::Util::Tagging)
  end

  it "should create a timestamp at its creation time" do
    expect(Oregano::Transaction::Event.new.time).to be_instance_of(Time)
  end

  describe "audit property" do
    it "should default to false" do
      expect(Oregano::Transaction::Event.new.audited).to eq(false)
    end
  end

  describe "when sending logs" do
    before do
      Oregano::Util::Log.stubs(:new)
    end

    it "should set the level to the resources's log level if the event status is 'success' and a resource is available" do
      resource = stub 'resource'
      resource.expects(:[]).with(:loglevel).returns :myloglevel
      Oregano::Util::Log.expects(:create).with { |args| args[:level] == :myloglevel }
      Oregano::Transaction::Event.new(:status => "success", :resource => resource).send_log
    end

    it "should set the level to 'notice' if the event status is 'success' and no resource is available" do
      Oregano::Util::Log.expects(:new).with { |args| args[:level] == :notice }
      Oregano::Transaction::Event.new(:status => "success").send_log
    end

    it "should set the level to 'notice' if the event status is 'noop'" do
      Oregano::Util::Log.expects(:new).with { |args| args[:level] == :notice }
      Oregano::Transaction::Event.new(:status => "noop").send_log
    end

    it "should set the level to 'err' if the event status is 'failure'" do
      Oregano::Util::Log.expects(:new).with { |args| args[:level] == :err }
      Oregano::Transaction::Event.new(:status => "failure").send_log
    end

    it "should set the 'message' to the event log" do
      Oregano::Util::Log.expects(:new).with { |args| args[:message] == "my message" }
      Oregano::Transaction::Event.new(:message => "my message").send_log
    end

    it "should set the tags to the event tags" do
      Oregano::Util::Log.expects(:new).with { |args| expect(args[:tags].to_a).to match_array(%w{one two}) }
      Oregano::Transaction::Event.new(:tags => %w{one two}).send_log
    end

    [:file, :line].each do |attr|
      it "should pass the #{attr}" do
        Oregano::Util::Log.expects(:new).with { |args| args[attr] == "my val" }
        Oregano::Transaction::Event.new(attr => "my val").send_log
      end
    end

    it "should use the source description as the source if one is set" do
      Oregano::Util::Log.expects(:new).with { |args| args[:source] == "/my/param" }
      Oregano::Transaction::Event.new(:source_description => "/my/param", :resource => TestResource.new, :property => "foo").send_log
    end

    it "should use the property as the source if one is available and no source description is set" do
      Oregano::Util::Log.expects(:new).with { |args| args[:source] == "foo" }
      Oregano::Transaction::Event.new(:resource => TestResource.new, :property => "foo").send_log
    end

    it "should use the property as the source if one is available and no property or source description is set" do
      Oregano::Util::Log.expects(:new).with { |args| args[:source] == "Foo[bar]" }
      Oregano::Transaction::Event.new(:resource => TestResource.new).send_log
    end
  end

  describe "When converting to YAML" do
    let(:resource) { Oregano::Type.type(:file).new(:title => make_absolute('/tmp/foo')) }
    let(:event) do
      Oregano::Transaction::Event.new(:source_description => "/my/param", :resource => resource,
        :file => "/foo.rb", :line => 27, :tags => %w{one two},
        :desired_value => 7, :historical_value => 'Brazil',
        :message => "Help I'm trapped in a spec test",
        :name => :mode_changed, :previous_value => 6, :property => :mode,
        :status => 'success',
        :redacted => false,
        :corrective_change => false)
    end

    it 'to_data_hash returns value that is instance of to Data' do
      expect(Oregano::Pops::Types::TypeFactory.data.instance?(event.to_data_hash)).to be_truthy
    end
  end

  it "should round trip through json" do
      resource = Oregano::Type.type(:file).new(:title => make_absolute("/tmp/foo"))
      event = Oregano::Transaction::Event.new(
        :source_description => "/my/param",
        :resource => resource,
        :file => "/foo.rb",
        :line => 27,
        :tags => %w{one two},
        :desired_value => 7,
        :historical_value => 'Brazil',
        :message => "Help I'm trapped in a spec test",
        :name => :mode_changed,
        :previous_value => 6,
        :property => :mode,
        :status => 'success')

      tripped = Oregano::Transaction::Event.from_data_hash(JSON.parse(event.to_json))

      expect(tripped.audited).to eq(event.audited)
      expect(tripped.property).to eq(event.property)
      expect(tripped.previous_value).to eq(event.previous_value)
      expect(tripped.desired_value).to eq(event.desired_value)
      expect(tripped.historical_value).to eq(event.historical_value)
      expect(tripped.message).to eq(event.message)
      expect(tripped.name).to eq(event.name)
      expect(tripped.status).to eq(event.status)
      expect(tripped.time).to eq(event.time)
  end

  it "should round trip an event for an inspect report through json" do
      resource = Oregano::Type.type(:file).new(:title => make_absolute("/tmp/foo"))
      event = Oregano::Transaction::Event.new(
        :audited => true,
        :source_description => "/my/param",
        :resource => resource,
        :file => "/foo.rb",
        :line => 27,
        :tags => %w{one two},
        :message => "Help I'm trapped in a spec test",
        :previous_value => 6,
        :property => :mode,
        :status => 'success')

      tripped = Oregano::Transaction::Event.from_data_hash(JSON.parse(event.to_json))

      expect(tripped.desired_value).to be_nil
      expect(tripped.historical_value).to be_nil
      expect(tripped.name).to be_nil

      expect(tripped.audited).to eq(event.audited)
      expect(tripped.property).to eq(event.property)
      expect(tripped.previous_value).to eq(event.previous_value)
      expect(tripped.message).to eq(event.message)
      expect(tripped.status).to eq(event.status)
      expect(tripped.time).to eq(event.time)
  end
end
