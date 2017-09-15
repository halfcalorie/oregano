#! /usr/bin/env ruby
require 'spec_helper'
require 'json'

require 'oregano/util/log'

describe Oregano::Util::Log.desttypes[:report] do
  before do
    @dest = Oregano::Util::Log.desttypes[:report]
  end

  it "should require a report at initialization" do
    expect(@dest.new("foo").report).to eq("foo")
  end

  it "should send new messages to the report" do
    report = mock 'report'
    dest = @dest.new(report)

    report.expects(:<<).with("my log")

    dest.handle "my log"
  end
end


describe Oregano::Util::Log.desttypes[:file] do
  include OreganoSpec::Files

  before do
    @class = Oregano::Util::Log.desttypes[:file]
  end

  it "should default to autoflush false" do
    expect(@class.new(tmpfile('log')).autoflush).to eq(true)
  end

  describe "when matching" do
    shared_examples_for "file destination" do
      it "should match an absolute path" do
        expect(@class.match?(abspath)).to be_truthy
      end

      it "should not match a relative path" do
        expect(@class.match?(relpath)).to be_falsey
      end
    end

    describe "on POSIX systems", :if => Oregano.features.posix? do
      let (:abspath) { '/tmp/log' }
      let (:relpath) { 'log' }

      it_behaves_like "file destination"

      it "logs an error if it can't chown the file owner & group" do
        FileUtils.expects(:chown).with(Oregano[:user], Oregano[:group], abspath).raises(Errno::EPERM)
        Oregano.features.expects(:root?).returns(true)
        Oregano.expects(:err).with("Unable to set ownership to #{Oregano[:user]}:#{Oregano[:group]} for log file: #{abspath}")

        @class.new(abspath)
      end

      it "doesn't attempt to chown when running as non-root" do
        FileUtils.expects(:chown).with(Oregano[:user], Oregano[:group], abspath).never
        Oregano.features.expects(:root?).returns(false)

        @class.new(abspath)
      end
    end

    describe "on Windows systems", :if => Oregano.features.microsoft_windows? do
      let (:abspath) { 'C:\\temp\\log.txt' }
      let (:relpath) { 'log.txt' }

      it_behaves_like "file destination"
    end
  end
end

describe Oregano::Util::Log.desttypes[:syslog] do
  let (:klass) { Oregano::Util::Log.desttypes[:syslog] }

  # these tests can only be run when syslog is present, because
  # we can't stub the top-level Syslog module
  describe "when syslog is available", :if => Oregano.features.syslog? do
    before :each do
      Syslog.stubs(:opened?).returns(false)
      Syslog.stubs(:const_get).returns("LOG_KERN").returns(0)
      Syslog.stubs(:open)
    end

    it "should open syslog" do
      Syslog.expects(:open)

      klass.new
    end

    it "should close syslog" do
      Syslog.expects(:close)

      dest = klass.new
      dest.close
    end

    it "should send messages to syslog" do
      syslog = mock 'syslog'
      syslog.expects(:info).with("don't panic")
      Syslog.stubs(:open).returns(syslog)

      msg = Oregano::Util::Log.new(:level => :info, :message => "don't panic")
      dest = klass.new
      dest.handle(msg)
    end
  end

  describe "when syslog is unavailable" do
    it "should not be a suitable log destination" do
      Oregano.features.stubs(:syslog?).returns(false)

      expect(klass.suitable?(:syslog)).to be_falsey
    end
  end
end

describe Oregano::Util::Log.desttypes[:logstash_event] do

  describe "when using structured log format with logstash_event schema" do
    before :each do
      @msg = Oregano::Util::Log.new(:level => :info, :message => "So long, and thanks for all the fish.", :source => "a dolphin")
    end

    it "format should fix the hash to have the correct structure" do
      dest = described_class.new
      result = dest.format(@msg)
      expect(result["version"]).to eq(1)
      expect(result["level"]).to   eq('info')
      expect(result["message"]).to eq("So long, and thanks for all the fish.")
      expect(result["source"]).to  eq("a dolphin")
      # timestamp should be within 10 seconds
      expect(Time.parse(result["@timestamp"])).to be >= ( Time.now - 10 )
    end

    it "format returns a structure that can be converted to json" do
      dest = described_class.new
      hash = dest.format(@msg)
      JSON.parse(hash.to_json)
    end

    it "handle should send the output to stdout" do
      $stdout.expects(:puts).once
      dest = described_class.new
      dest.handle(@msg)
    end
  end
end

describe Oregano::Util::Log.desttypes[:console] do
  let (:klass) { Oregano::Util::Log.desttypes[:console] }

  it "should support color output" do
    Oregano[:color] = true
    expect(subject.colorize(:red, 'version')).to eq("\e[0;31mversion\e[0m")
  end

  it "should withhold color output when not appropriate" do
    Oregano[:color] = false
    expect(subject.colorize(:red, 'version')).to eq("version")
  end

  it "should handle multiple overlapping colors in a stack-like way" do
    Oregano[:color] = true
    vstring = subject.colorize(:red, 'version')
    expect(subject.colorize(:green, "(#{vstring})")).to eq("\e[0;32m(\e[0;31mversion\e[0;32m)\e[0m")
  end

  it "should handle resets in a stack-like way" do
    Oregano[:color] = true
    vstring = subject.colorize(:reset, 'version')
    expect(subject.colorize(:green, "(#{vstring})")).to eq("\e[0;32m(\e[mversion\e[0;32m)\e[0m")
  end

  it "should include the log message's source/context in the output when available" do
    Oregano[:color] = false
    $stdout.expects(:puts).with("Info: a hitchhiker: don't panic")

    msg = Oregano::Util::Log.new(:level => :info, :message => "don't panic", :source => "a hitchhiker")
    dest = klass.new
    dest.handle(msg)
  end
end


describe ":eventlog", :if => Oregano::Util::Platform.windows? do
  let(:klass) { Oregano::Util::Log.desttypes[:eventlog] }

  def expects_message_with_type(klass, level, eventlog_type, eventlog_id)
    eventlog = stub('eventlog')
    eventlog.expects(:report_event).with(has_entries(:event_type => eventlog_type, :event_id => eventlog_id, :data => "a hitchhiker: don't panic"))
    Oregano::Util::Windows::EventLog.stubs(:open).returns(eventlog)

    msg = Oregano::Util::Log.new(:level => level, :message => "don't panic", :source => "a hitchhiker")
    dest = klass.new
    dest.handle(msg)
  end

  it "supports the eventlog feature" do
    expect(Oregano.features.eventlog?).to be_truthy
  end

  it "logs to the Oregano Application event log" do
    Oregano::Util::Windows::EventLog.expects(:open).with('Oregano').returns(stub('eventlog'))

    klass.new
  end

  it "logs :debug level as an information type event" do
    expects_message_with_type(klass, :debug, klass::EVENTLOG_INFORMATION_TYPE, 0x1)
  end

  it "logs :warning level as an warning type event" do
    expects_message_with_type(klass, :warning, klass::EVENTLOG_WARNING_TYPE, 0x2)
  end

  it "logs :err level as an error type event" do
    expects_message_with_type(klass, :err, klass::EVENTLOG_ERROR_TYPE, 0x3)
  end
end
