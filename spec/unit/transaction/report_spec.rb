#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano'
require 'oregano/transaction/report'
require 'matchers/json'

describe Oregano::Transaction::Report do
  include JSONMatchers
  include OreganoSpec::Files

  before do
    Oregano::Util::Storage.stubs(:store)
  end

  it "should set its host name to the node_name_value" do
    Oregano[:node_name_value] = 'mynode'
    expect(Oregano::Transaction::Report.new.host).to eq("mynode")
  end

  it "should return its host name as its name" do
    r = Oregano::Transaction::Report.new
    expect(r.name).to eq(r.host)
  end

  it "should create an initialization timestamp" do
    Time.expects(:now).returns "mytime"
    expect(Oregano::Transaction::Report.new.time).to eq("mytime")
  end

  it "should take a 'configuration_version' as an argument" do
    expect(Oregano::Transaction::Report.new("some configuration version", "some environment").configuration_version).to eq("some configuration version")
  end

  it "should take a 'transaction_uuid' as an argument" do
    expect(Oregano::Transaction::Report.new("some configuration version", "some environment", "some transaction uuid").transaction_uuid).to eq("some transaction uuid")
  end

  it "should take a 'transaction_uuid' as an argument" do
    expect(Oregano::Transaction::Report.new("some configuration version", "some environment", "some transaction uuid").transaction_uuid).to eq("some transaction uuid")
  end

  it "should take a 'job_id' as an argument" do
    expect(Oregano::Transaction::Report.new('cv', 'env', 'tid', 'some job id').job_id).to eq('some job id')
  end

  it "should be able to set configuration_version" do
    report = Oregano::Transaction::Report.new
    report.configuration_version = "some version"
    expect(report.configuration_version).to eq("some version")
  end

  it "should be able to set transaction_uuid" do
    report = Oregano::Transaction::Report.new
    report.transaction_uuid = "some transaction uuid"
    expect(report.transaction_uuid).to eq("some transaction uuid")
  end

  it "should be able to set job_id" do
    report = Oregano::Transaction::Report.new
    report.job_id = "some job id"
    expect(report.job_id).to eq("some job id")
  end

  it "should be able to set code_id" do
    report = Oregano::Transaction::Report.new
    report.code_id = "some code id"
    expect(report.code_id).to eq("some code id")
  end

  it "should be able to set catalog_uuid" do
    report = Oregano::Transaction::Report.new
    report.catalog_uuid = "some catalog uuid"
    expect(report.catalog_uuid).to eq("some catalog uuid")
  end

  it "should be able to set cached_catalog_status" do
    report = Oregano::Transaction::Report.new
    report.cached_catalog_status = "explicitly_requested"
    expect(report.cached_catalog_status).to eq("explicitly_requested")
  end

  it "should set noop to true if Oregano[:noop] is true" do
    Oregano[:noop] = true
    report = Oregano::Transaction::Report.new
    expect(report.noop).to be_truthy
  end

  it "should set noop to false if Oregano[:noop] is false" do
    Oregano[:noop] = false
    report = Oregano::Transaction::Report.new
    expect(report.noop).to be_falsey
  end

  it "should set noop to false if Oregano[:noop] is unset" do
    Oregano[:noop] = nil
    report = Oregano::Transaction::Report.new
    expect(report.noop).to be_falsey
  end

  it "should take 'environment' as an argument" do
    expect(Oregano::Transaction::Report.new("some configuration version", "some environment").environment).to eq("some environment")
  end

  it "should be able to set environment" do
    report = Oregano::Transaction::Report.new
    report.environment = "some environment"
    expect(report.environment).to eq("some environment")
  end

  it "should be able to set resources_failed_to_generate" do
    report = Oregano::Transaction::Report.new
    report.resources_failed_to_generate = true
    expect(report.resources_failed_to_generate).to be_truthy
  end

  it "resources_failed_to_generate should not be true by default" do
    report = Oregano::Transaction::Report.new
    expect(report.resources_failed_to_generate).to be_falsey
  end

  it "should not include whits" do
    Oregano::FileBucket::File.indirection.stubs(:save)

    filename = tmpfile('whit_test')
    file = Oregano::Type.type(:file).new(:path => filename)

    catalog = Oregano::Resource::Catalog.new
    catalog.add_resource(file)

    report = Oregano::Transaction::Report.new

    catalog.apply(:report => report)
    report.finalize_report

    expect(report.resource_statuses.values.any? {|res| res.resource_type =~ /whit/i}).to be_falsey
    expect(report.metrics['time'].values.any? {|metric| metric.first =~ /whit/i}).to be_falsey
  end

  describe "when accepting logs" do
    before do
      @report = Oregano::Transaction::Report.new
    end

    it "should add new logs to the log list" do
      @report << "log"
      expect(@report.logs[-1]).to eq("log")
    end

    it "should return self" do
      r = @report << "log"
      expect(r).to equal(@report)
    end
  end

  describe "#as_logging_destination" do
    it "makes the report collect logs during the block " do
      log_string = 'Hello test report!'
      report = Oregano::Transaction::Report.new
      report.as_logging_destination do
        Oregano.err(log_string)
      end

      expect(report.logs.collect(&:message)).to include(log_string)
    end
  end

  describe "when accepting resource statuses" do
    before do
      @report = Oregano::Transaction::Report.new
    end

    it "should add each status to its status list" do
      status = stub 'status', :resource => "foo"
      @report.add_resource_status status
      expect(@report.resource_statuses["foo"]).to equal(status)
    end
  end

  describe "when using the indirector" do
    it "should redirect :save to the indirection" do
      Facter.stubs(:value).returns("eh")
      @indirection = stub 'indirection', :name => :report
      Oregano::Transaction::Report.stubs(:indirection).returns(@indirection)
      report = Oregano::Transaction::Report.new
      @indirection.expects(:save)
      Oregano::Transaction::Report.indirection.save(report)
    end

    it "should default to the 'processor' terminus" do
      expect(Oregano::Transaction::Report.indirection.terminus_class).to eq(:processor)
    end

    it "should delegate its name attribute to its host method" do
      report = Oregano::Transaction::Report.new
      report.expects(:host).returns "me"
      expect(report.name).to eq("me")
    end
  end

  describe "when computing exit status" do
    it "should produce 2 if changes are present" do
      report = Oregano::Transaction::Report.new
      report.add_metric("changes", {"total" => 1})
      report.add_metric("resources", {"failed" => 0})
      expect(report.exit_status).to eq(2)
    end

    it "should produce 4 if failures are present" do
      report = Oregano::Transaction::Report.new
      report.add_metric("changes", {"total" => 0})
      report.add_metric("resources", {"failed" => 1})
      expect(report.exit_status).to eq(4)
    end

    it "should produce 4 if failures to restart are present" do
      report = Oregano::Transaction::Report.new
      report.add_metric("changes", {"total" => 0})
      report.add_metric("resources", {"failed" => 0})
      report.add_metric("resources", {"failed_to_restart" => 1})
      expect(report.exit_status).to eq(4)
    end

    it "should produce 6 if both changes and failures are present" do
      report = Oregano::Transaction::Report.new
      report.add_metric("changes", {"total" => 1})
      report.add_metric("resources", {"failed" => 1})
      expect(report.exit_status).to eq(6)
    end
  end

  describe "before finalizing the report" do
    it "should have a status of 'failed'" do
      report = Oregano::Transaction::Report.new
      expect(report.status).to eq('failed')
    end
  end

  describe "when finalizing the report" do
    before do
      @report = Oregano::Transaction::Report.new
    end

    def metric(name, value)
      if metric = @report.metrics[name.to_s]
        metric[value]
      else
        nil
      end
    end

    def add_statuses(count, type = :file)
      count.times do |i|
        status = Oregano::Resource::Status.new(Oregano::Type.type(type).new(:title => make_absolute("/my/path#{i}")))
        yield status if block_given?
        @report.add_resource_status status
      end
    end

    [:time, :resources, :changes, :events].each do |type|
      it "should add #{type} metrics" do
        @report.finalize_report
        expect(@report.metrics[type.to_s]).to be_instance_of(Oregano::Transaction::Metric)
      end
    end

    describe "for resources" do
      it "should provide the total number of resources" do
        add_statuses(3)

        @report.finalize_report
        expect(metric(:resources, "total")).to eq(3)
      end

      Oregano::Resource::Status::STATES.each do |state|
        it "should provide the number of #{state} resources as determined by the status objects" do
          add_statuses(3) { |status| status.send(state.to_s + "=", true) }

          @report.finalize_report
          expect(metric(:resources, state.to_s)).to eq(3)
        end

        it "should provide 0 for states not in status" do
          @report.finalize_report
          expect(metric(:resources, state.to_s)).to eq(0)
        end
      end

      it "should mark the report as 'failed' if there are failing resources" do
        add_statuses(1) { |status| status.failed = true }
        @report.finalize_report
        expect(@report.status).to eq('failed')
      end

      it "should mark the report as 'failed' if resources failed to restart" do
        add_statuses(1) { |status| status.failed_to_restart = true }
        @report.finalize_report
        expect(@report.status).to eq('failed')
      end

      it "should mark the report as 'failed' if resources_failed_to_generate" do
        @report.resources_failed_to_generate = true
        @report.finalize_report
        expect(@report.status).to eq('failed')
      end
    end

    describe "for changes" do
      it "should provide the number of changes from the resource statuses and mark the report as 'changed'" do
        add_statuses(3) { |status| 3.times { status << Oregano::Transaction::Event.new(:status => 'success') } }
        @report.finalize_report
        expect(metric(:changes, "total")).to eq(9)
        expect(@report.status).to eq('changed')
      end

      it "should provide a total even if there are no changes, and mark the report as 'unchanged'" do
        @report.finalize_report
        expect(metric(:changes, "total")).to eq(0)
        expect(@report.status).to eq('unchanged')
      end
    end

    describe "for times" do
      it "should provide the total amount of time for each resource type" do
        add_statuses(3, :file) do |status|
          status.evaluation_time = 1
        end
        add_statuses(3, :exec) do |status|
          status.evaluation_time = 2
        end
        add_statuses(3, :tidy) do |status|
          status.evaluation_time = 3
        end

        @report.finalize_report

        expect(metric(:time, "file")).to eq(3)
        expect(metric(:time, "exec")).to eq(6)
        expect(metric(:time, "tidy")).to eq(9)
      end

      it "should add any provided times from external sources" do
        @report.add_times :foobar, 50
        @report.finalize_report
        expect(metric(:time, "foobar")).to eq(50)
      end

      it "should have a total time" do
        add_statuses(3, :file) do |status|
          status.evaluation_time = 1.25
        end
        @report.add_times :config_retrieval, 0.5
        @report.finalize_report
        expect(metric(:time, "total")).to eq(4.25)
      end
    end

    describe "for events" do
      it "should provide the total number of events" do
        add_statuses(3) do |status|
          3.times { |i| status.add_event(Oregano::Transaction::Event.new :status => 'success') }
        end
        @report.finalize_report
        expect(metric(:events, "total")).to eq(9)
      end

      it "should provide the total even if there are no events" do
        @report.finalize_report
        expect(metric(:events, "total")).to eq(0)
      end

      Oregano::Transaction::Event::EVENT_STATUSES.each do |status_name|
        it "should provide the number of #{status_name} events" do
          add_statuses(3) do |status|
            3.times do |i|
              event = Oregano::Transaction::Event.new
              event.status = status_name
              status.add_event(event)
            end
          end

          @report.finalize_report
          expect(metric(:events, status_name)).to eq(9)
        end
      end
    end

    describe "for noop events" do
      it "should have 'noop_pending == false' when no events are available" do
        add_statuses(3)
        @report.finalize_report
        expect(@report.noop_pending).to be_falsey
      end

      it "should have 'noop_pending == false' when no 'noop' events are available" do
        add_statuses(3) do |status|
          ['success', 'audit'].each do |status_name|
            event = Oregano::Transaction::Event.new
            event.status = status_name
            status.add_event(event)
          end
        end
        @report.finalize_report
        expect(@report.noop_pending).to be_falsey
      end

      it "should have 'noop_pending == true' when 'noop' events are available" do
        add_statuses(3) do |status|
          ['success', 'audit', 'noop'].each do |status_name|
            event = Oregano::Transaction::Event.new
            event.status = status_name
            status.add_event(event)
          end
        end
        @report.finalize_report
        expect(@report.noop_pending).to be_truthy
      end

      it "should have 'noop_pending == true' when 'noop' and 'failure' events are available" do
        add_statuses(3) do |status|
          ['success', 'failure', 'audit', 'noop'].each do |status_name|
            event = Oregano::Transaction::Event.new
            event.status = status_name
            status.add_event(event)
          end
        end
        @report.finalize_report
        expect(@report.noop_pending).to be_truthy
      end
    end
  end

  describe "when producing a summary" do
    before do
      resource = Oregano::Type.type(:notify).new(:name => "testing")
      catalog = Oregano::Resource::Catalog.new
      catalog.add_resource resource
      catalog.version = 1234567
      trans = catalog.apply

      @report = trans.report
      @report.finalize_report
    end

    %w{changes time resources events version}.each do |main|
      it "should include the key #{main} in the raw summary hash" do
        expect(@report.raw_summary).to be_key main
      end
    end

    it "should include the last run time in the raw summary hash" do
      Time.stubs(:now).returns(Time.utc(2010,11,10,12,0,24))
      expect(@report.raw_summary["time"]["last_run"]).to eq(1289390424)
    end

    it "should include all resource statuses" do
      resources_report = @report.raw_summary["resources"]
      Oregano::Resource::Status::STATES.each do |state|
        expect(resources_report).to be_include(state.to_s)
      end
    end

    %w{total failure success}.each do |r|
      it "should include event #{r}" do
        events_report = @report.raw_summary["events"]
        expect(events_report).to be_include(r)
      end
    end

    it "should include config version" do
      expect(@report.raw_summary["version"]["config"]).to eq(1234567)
    end

    it "should include oregano version" do
      expect(@report.raw_summary["version"]["oregano"]).to eq(Oregano.version)
    end

    %w{Changes Total Resources Time Events}.each do |main|
      it "should include information on #{main} in the textual summary" do
        expect(@report.summary).to be_include(main)
      end
    end
  end

  describe "when outputting yaml" do
    it "should not include @external_times" do
      report = Oregano::Transaction::Report.new
      report.add_times('config_retrieval', 1.0)
      expect(report.to_data_hash.keys).not_to include('external_times')
    end

    it "should not include @resources_failed_to_generate" do
      report = Oregano::Transaction::Report.new
      report.resources_failed_to_generate = true
      expect(report.to_data_hash.keys).not_to include('resources_failed_to_generate')
    end

    it 'to_data_hash returns value that is instance of to Data' do
      expect(Oregano::Pops::Types::TypeFactory.data.instance?(generate_report.to_data_hash)).to be_truthy
    end
  end

  it "defaults to serializing to json" do
    expect(Oregano::Transaction::Report.default_format).to eq(:json)
  end

  it "supports both json, pson and yaml" do
    # msgpack is optional, so using include instead of eq
    expect(Oregano::Transaction::Report.supported_formats).to include(:json, :pson, :yaml)
  end

  context 'can make a round trip through' do
    before(:each) do
      Oregano.push_context(:loaders => Oregano::Pops::Loaders.new(Oregano.lookup(:current_environment)))
    end

    after(:each) { Oregano.pop_context }

    it 'pson' do
      report = generate_report

      tripped = Oregano::Transaction::Report.convert_from(:pson, report.render)

      expect_equivalent_reports(tripped, report)
    end

    it 'json' do
      report = generate_report

      tripped = Oregano::Transaction::Report.convert_from(:json, report.render)

      expect_equivalent_reports(tripped, report)
    end

    it 'yaml' do
      report = generate_report

      yaml_output = report.render(:yaml)
      tripped = Oregano::Transaction::Report.convert_from(:yaml, yaml_output)

      expect(yaml_output).to match(/^--- /)
      expect_equivalent_reports(tripped, report)
    end
  end

  it "generates json which validates against the report schema" do
    report = generate_report
    expect(report.render).to validate_against('api/schemas/report.json')
  end

  it "generates json for error report which validates against the report schema" do
    error_report = generate_report_with_error
    expect(error_report.render).to validate_against('api/schemas/report.json')
  end

  def expect_equivalent_reports(tripped, report)
    expect(tripped.host).to eq(report.host)
    expect(tripped.time.to_i).to eq(report.time.to_i)
    expect(tripped.configuration_version).to eq(report.configuration_version)
    expect(tripped.transaction_uuid).to eq(report.transaction_uuid)
    expect(tripped.job_id).to eq(report.job_id)
    expect(tripped.code_id).to eq(report.code_id)
    expect(tripped.catalog_uuid).to eq(report.catalog_uuid)
    expect(tripped.cached_catalog_status).to eq(report.cached_catalog_status)
    expect(tripped.report_format).to eq(report.report_format)
    expect(tripped.oregano_version).to eq(report.oregano_version)
    expect(tripped.status).to eq(report.status)
    expect(tripped.environment).to eq(report.environment)
    expect(tripped.corrective_change).to eq(report.corrective_change)

    expect(logs_as_strings(tripped)).to eq(logs_as_strings(report))
    expect(metrics_as_hashes(tripped)).to eq(metrics_as_hashes(report))
    expect_equivalent_resource_statuses(tripped.resource_statuses, report.resource_statuses)
  end

  def logs_as_strings(report)
    report.logs.map(&:to_report)
  end

  def metrics_as_hashes(report)
    Hash[*report.metrics.collect do |name, m|
      [name, { :name => m.name, :label => m.label, :value => m.value }]
    end.flatten]
  end

  def expect_equivalent_resource_statuses(tripped, report)
    expect(tripped.keys.sort).to eq(report.keys.sort)

    tripped.each_pair do |name, status|
      expected = report[name]

      expect(status.title).to eq(expected.title)
      expect(status.file).to eq(expected.file)
      expect(status.line).to eq(expected.line)
      expect(status.resource).to eq(expected.resource)
      expect(status.resource_type).to eq(expected.resource_type)
      expect(status.containment_path).to eq(expected.containment_path)
      expect(status.evaluation_time).to eq(expected.evaluation_time)
      expect(status.tags).to eq(expected.tags)
      expect(status.time.to_i).to eq(expected.time.to_i)
      expect(status.failed).to eq(expected.failed)
      expect(status.changed).to eq(expected.changed)
      expect(status.out_of_sync).to eq(expected.out_of_sync)
      expect(status.skipped).to eq(expected.skipped)
      expect(status.change_count).to eq(expected.change_count)
      expect(status.out_of_sync_count).to eq(expected.out_of_sync_count)
      expect(status.events).to eq(expected.events)
    end
  end

  def generate_report
    event_hash = {
      :audited => false,
      :property => 'message',
      :previous_value => SemanticOregano::VersionRange.parse('>=1.0.0'),
      :desired_value => SemanticOregano::VersionRange.parse('>=1.2.0'),
      :historical_value => nil,
      :message => "defined 'message' as 'a resource'",
      :name => :message_changed,
      :status => 'success',
    }
    event = Oregano::Transaction::Event.new(event_hash)

    status = Oregano::Resource::Status.new(Oregano::Type.type(:notify).new(:title => "a resource"))
    status.changed = true
    status.add_event(event)

    report = Oregano::Transaction::Report.new(1357986, 'test_environment', "df34516e-4050-402d-a166-05b03b940749", '42')
    report << Oregano::Util::Log.new(:level => :warning, :message => "log message")
    report.add_times("timing", 4)
    report.code_id = "some code id"
    report.catalog_uuid = "some catalog uuid"
    report.cached_catalog_status = "not_used"
    report.master_used = "test:000"
    report.add_resource_status(status)
    report.finalize_report
    report
  end

  def generate_report_with_error
    status = Oregano::Resource::Status.new(Oregano::Type.type(:notify).new(:title => "a resource"))
    status.changed = true
    status.failed_because("bad stuff happened")

    report = Oregano::Transaction::Report.new(1357986, 'test_environment', "df34516e-4050-402d-a166-05b03b940749", '42')
    report << Oregano::Util::Log.new(:level => :warning, :message => "log message")
    report.add_times("timing", 4)
    report.code_id = "some code id"
    report.catalog_uuid = "some catalog uuid"
    report.cached_catalog_status = "not_used"
    report.master_used = "test:000"
    report.add_resource_status(status)
    report.finalize_report
    report
  end

end
