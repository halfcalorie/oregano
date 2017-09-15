#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/configurer'

describe Oregano::Configurer do
  before do
    Oregano.settings.stubs(:use).returns(true)
    @agent = Oregano::Configurer.new
    @agent.stubs(:init_storage)
    Oregano::Util::Storage.stubs(:store)
    Oregano[:server] = "oreganomaster"
    Oregano[:report] = true
  end

  it "should include the Fact Handler module" do
    expect(Oregano::Configurer.ancestors).to be_include(Oregano::Configurer::FactHandler)
  end

  describe "when executing a pre-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Oregano.settings[:prerun_command] = ""
      Oregano::Util.expects(:exec).never

      @agent.execute_prerun_command
    end

    it "should execute any pre-run command provided via the 'prerun_command' setting" do
      Oregano.settings[:prerun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      @agent.execute_prerun_command
    end

    it "should fail if the command fails" do
      Oregano.settings[:prerun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      expect(@agent.execute_prerun_command).to be_falsey
    end
  end

  describe "when executing a post-run hook" do
    it "should do nothing if the hook is set to an empty string" do
      Oregano.settings[:postrun_command] = ""
      Oregano::Util.expects(:exec).never

      @agent.execute_postrun_command
    end

    it "should execute any post-run command provided via the 'postrun_command' setting" do
      Oregano.settings[:postrun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      @agent.execute_postrun_command
    end

    it "should fail if the command fails" do
      Oregano.settings[:postrun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      expect(@agent.execute_postrun_command).to be_falsey
    end
  end

  describe "when executing a catalog run" do
    before do
      Oregano.settings.stubs(:use).returns(true)
      @agent.stubs(:download_plugins)
      Oregano::Node::Facts.indirection.terminus_class = :memory
      @facts = Oregano::Node::Facts.new(Oregano[:node_name_value])
      Oregano::Node::Facts.indirection.save(@facts)

      @catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote(Oregano[:environment].to_sym))
      @catalog.stubs(:to_ral).returns(@catalog)
      Oregano::Resource::Catalog.indirection.terminus_class = :rest
      Oregano::Resource::Catalog.indirection.stubs(:find).returns(@catalog)
      @agent.stubs(:send_report)
      @agent.stubs(:save_last_run_summary)

      Oregano::Util::Log.stubs(:close_all)
    end

    after :all do
      Oregano::Node::Facts.indirection.reset_terminus_class
      Oregano::Resource::Catalog.indirection.reset_terminus_class
    end

    it "should initialize storage" do
      Oregano::Util::Storage.expects(:load)
      @agent.run
    end

    it "downloads plugins when told" do
      @agent.expects(:download_plugins)
      @agent.run(:pluginsync => true)
    end

    it "does not download plugins when told" do
      @agent.expects(:download_plugins).never
      @agent.run(:pluginsync => false)
    end

    it "should carry on when it can't fetch its node definition" do
      error = Net::HTTPError.new(400, 'dummy server communication error')
      Oregano::Node.indirection.expects(:find).raises(error)
      expect(@agent.run).to eq(0)
    end

    it "applies a cached catalog when it can't connect to the master" do
      error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')

      Oregano::Node.indirection.expects(:find).raises(error)
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entry(:ignore_cache => true)).raises(error)
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entry(:ignore_terminus => true)).returns(@catalog)

      expect(@agent.run).to eq(0)
    end

    it "should initialize a transaction report if one is not provided" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns report

      @agent.run
    end

    it "should respect node_name_fact when setting the host on a report" do
      Oregano[:node_name_fact] = 'my_name_fact'
      @facts.values = {'my_name_fact' => 'node_name_from_fact'}

      report = Oregano::Transaction::Report.new

      @agent.run(:report => report)
      expect(report.host).to eq('node_name_from_fact')
    end

    it "should pass the new report to the catalog" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.stubs(:new).returns report
      @catalog.expects(:apply).with{|options| options[:report] == report}

      @agent.run
    end

    it "should use the provided report if it was passed one" do
      report = Oregano::Transaction::Report.new
      @catalog.expects(:apply).with {|options| options[:report] == report}

      @agent.run(:report => report)
    end

    it "should set the report as a log destination" do
      report = Oregano::Transaction::Report.new

      report.expects(:<<).with(instance_of(Oregano::Util::Log)).at_least_once

      @agent.run(:report => report)
    end

    it "should retrieve the catalog" do
      @agent.expects(:retrieve_catalog)

      @agent.run
    end

    it "should log a failure and do nothing if no catalog can be retrieved" do
      @agent.expects(:retrieve_catalog).returns nil

      Oregano.expects(:err).with "Could not retrieve catalog; skipping run"

      @agent.run
    end

    it "should apply the catalog with all options to :run" do
      @agent.expects(:retrieve_catalog).returns @catalog

      @catalog.expects(:apply).with { |args| args[:one] == true }
      @agent.run :one => true
    end

    it "should accept a catalog and use it instead of retrieving a different one" do
      @agent.expects(:retrieve_catalog).never

      @catalog.expects(:apply)
      @agent.run :one => true, :catalog => @catalog
    end

    it "should benchmark how long it takes to apply the catalog" do
      @agent.expects(:benchmark).with(:notice, instance_of(String))

      @agent.expects(:retrieve_catalog).returns @catalog

      @catalog.expects(:apply).never # because we're not yielding
      @agent.run
    end

    it "should execute post-run hooks after the run" do
      @agent.expects(:execute_postrun_command)

      @agent.run
    end

    it "should create report with passed transaction_uuid and job_id" do
      @agent = Oregano::Configurer.new(Oregano::Configurer::DownloaderFactory.new, "test_tuuid", "test_jid")
      @agent.stubs(:init_storage)

      report = Oregano::Transaction::Report.new(nil, "test", "aaaa")
      Oregano::Transaction::Report.expects(:new).with(anything, anything, 'test_tuuid', 'test_jid').returns(report)
      @agent.expects(:send_report).with(report)

      @agent.run
    end

    it "should send the report" do
      report = Oregano::Transaction::Report.new(nil, "test", "aaaa")
      Oregano::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      @agent.run
    end

    it "should send the transaction report even if the catalog could not be retrieved" do
      @agent.expects(:retrieve_catalog).returns nil

      report = Oregano::Transaction::Report.new(nil, "test", "aaaa")
      Oregano::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      @agent.run
    end

    it "should send the transaction report even if there is a failure" do
      @agent.expects(:retrieve_catalog).raises "whatever"

      report = Oregano::Transaction::Report.new(nil, "test", "aaaa")
      Oregano::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      expect(report.environment).to eq("test")
      expect(report.transaction_uuid).to eq("aaaa")

      expect(@agent.run).to be_nil
    end

    it "should remove the report as a log destination when the run is finished" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      @agent.run

      expect(Oregano::Util::Log.destinations).not_to include(report)
    end

    it "should return the report exit_status as the result of the run" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)
      report.expects(:exit_status).returns(1234)

      expect(@agent.run).to eq(1234)
    end

    it "should send the transaction report even if the pre-run command fails" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:prerun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")
      @agent.expects(:send_report).with(report)

      expect(@agent.run).to be_nil
    end

    it "should include the pre-run command failure in the report" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:prerun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      expect(@agent.run).to be_nil
      expect(report.logs.find { |x| x.message =~ /Could not run command from prerun_command/ }).to be
    end

    it "should send the transaction report even if the post-run command fails" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:postrun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")
      @agent.expects(:send_report).with(report)

      expect(@agent.run).to be_nil
    end

    it "should include the post-run command failure in the report" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:postrun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      report.expects(:<<).with { |log| log.message.include?("Could not run command from postrun_command") }

      expect(@agent.run).to be_nil
    end

    it "should execute post-run command even if the pre-run command fails" do
      Oregano.settings[:prerun_command] = "/my/precommand"
      Oregano.settings[:postrun_command] = "/my/postcommand"
      Oregano::Util::Execution.expects(:execute).with(["/my/precommand"]).raises(Oregano::ExecutionFailure, "Failed")
      Oregano::Util::Execution.expects(:execute).with(["/my/postcommand"])

      expect(@agent.run).to be_nil
    end

    it "should finalize the report" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      report.expects(:finalize_report)
      @agent.run
    end

    it "should not apply the catalog if the pre-run command fails" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:prerun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      @catalog.expects(:apply).never()
      @agent.expects(:send_report)

      expect(@agent.run).to be_nil
    end

    it "should apply the catalog, send the report, and return nil if the post-run command fails" do
      report = Oregano::Transaction::Report.new
      Oregano::Transaction::Report.expects(:new).returns(report)

      Oregano.settings[:postrun_command] = "/my/command"
      Oregano::Util::Execution.expects(:execute).with(["/my/command"]).raises(Oregano::ExecutionFailure, "Failed")

      @catalog.expects(:apply)
      @agent.expects(:send_report)

      expect(@agent.run).to be_nil
    end

    it "should refetch the catalog if the server specifies a new environment in the catalog" do
      catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote('second_env'))
      @agent.expects(:retrieve_catalog).returns(catalog).twice

      @agent.run
    end

    it "should change the environment setting if the server specifies a new environment in the catalog" do
      @catalog.stubs(:environment).returns("second_env")

      @agent.run

      expect(@agent.environment).to eq("second_env")
    end

    it "should fix the report if the server specifies a new environment in the catalog" do
      report = Oregano::Transaction::Report.new(nil, "test", "aaaa")
      Oregano::Transaction::Report.expects(:new).returns(report)
      @agent.expects(:send_report).with(report)

      @catalog.stubs(:environment).returns("second_env")
      @agent.stubs(:retrieve_catalog).returns(@catalog)

      @agent.run

      expect(report.environment).to eq("second_env")
    end

    it "sends the transaction uuid in a catalog request" do
      @agent.instance_variable_set(:@transaction_uuid, 'aaa')
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entries(:transaction_uuid => 'aaa'))
      @agent.run
    end

    it "sends the transaction uuid in a catalog request" do
      @agent.instance_variable_set(:@job_id, 'aaa')
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entries(:job_id => 'aaa'))
      @agent.run
    end

    it "sets the static_catalog query param to true in a catalog request" do
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entries(:static_catalog => true))
      @agent.run
    end

    it "sets the checksum_type query param to the default supported_checksum_types in a catalog request" do
      Oregano::Resource::Catalog.indirection.expects(:find).with(anything,
        has_entries(:checksum_type => 'md5.sha256'))
      @agent.run
    end

    it "sets the checksum_type query param to the supported_checksum_types setting in a catalog request" do
      # Regenerate the agent to pick up the new setting
      Oregano[:supported_checksum_types] = ['sha256']
      @agent = Oregano::Configurer.new
      @agent.stubs(:init_storage)
      @agent.stubs(:download_plugins)
      @agent.stubs(:send_report)
      @agent.stubs(:save_last_run_summary)

      Oregano::Resource::Catalog.indirection.expects(:find).with(anything, has_entries(:checksum_type => 'sha256'))
      @agent.run
    end

    describe "when not using a REST terminus for catalogs" do
      it "should not pass any facts when retrieving the catalog" do
        Oregano::Resource::Catalog.indirection.terminus_class = :compiler
        @agent.expects(:facts_for_uploading).never
        Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options|
          options[:facts].nil?
        }.returns @catalog

        @agent.run
      end
    end

    describe "when using a REST terminus for catalogs" do
      it "should pass the prepared facts and the facts format as arguments when retrieving the catalog" do
        Oregano::Resource::Catalog.indirection.terminus_class = :rest
        @agent.expects(:facts_for_uploading).returns(:facts => "myfacts", :facts_format => :foo)
        Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options|
          options[:facts] == "myfacts" and options[:facts_format] == :foo
        }.returns @catalog

        @agent.run
      end
    end
  end

  describe "when initialized with a transaction_uuid" do
    it "stores it" do
      SecureRandom.expects(:uuid).never
      configurer = Oregano::Configurer.new(Oregano::Configurer::DownloaderFactory.new, 'foo')
      expect(configurer.instance_variable_get(:@transaction_uuid) == 'foo')
    end
  end

  describe "when sending a report" do
    include OreganoSpec::Files

    before do
      Oregano.settings.stubs(:use).returns(true)
      @configurer = Oregano::Configurer.new
      Oregano[:lastrunfile] = tmpfile('last_run_file')

      @report = Oregano::Transaction::Report.new
      Oregano[:reports] = "none"
    end

    it "should print a report summary if configured to do so" do
      Oregano.settings[:summarize] = true

      @report.expects(:summary).returns "stuff"

      @configurer.expects(:puts).with("stuff")
      @configurer.send_report(@report)
    end

    it "should not print a report summary if not configured to do so" do
      Oregano.settings[:summarize] = false

      @configurer.expects(:puts).never
      @configurer.send_report(@report)
    end

    it "should save the report if reporting is enabled" do
      Oregano.settings[:report] = true

      Oregano::Transaction::Report.indirection.expects(:save).with(@report, nil, instance_of(Hash))
      @configurer.send_report(@report)
    end

    it "should not save the report if reporting is disabled" do
      Oregano.settings[:report] = false

      Oregano::Transaction::Report.indirection.expects(:save).with(@report, nil, instance_of(Hash)).never
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is enabled" do
      Oregano.settings[:report] = true

      @configurer.expects(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should save the last run summary if reporting is disabled" do
      Oregano.settings[:report] = false

      @configurer.expects(:save_last_run_summary).with(@report)
      @configurer.send_report(@report)
    end

    it "should log but not fail if saving the report fails" do
      Oregano.settings[:report] = true

      Oregano::Transaction::Report.indirection.expects(:save).raises("whatever")

      Oregano.expects(:err)
      expect { @configurer.send_report(@report) }.not_to raise_error
    end
  end

  describe "when saving the summary report file" do
    include OreganoSpec::Files

    before do
      Oregano.settings.stubs(:use).returns(true)
      @configurer = Oregano::Configurer.new

      @report = stub 'report', :raw_summary => {}

      Oregano[:lastrunfile] = tmpfile('last_run_file')
    end

    it "should write the last run file" do
      @configurer.save_last_run_summary(@report)
      expect(Oregano::FileSystem.exist?(Oregano[:lastrunfile])).to be_truthy
    end

    it "should write the raw summary as yaml" do
      @report.expects(:raw_summary).returns("summary")
      @configurer.save_last_run_summary(@report)
      expect(File.read(Oregano[:lastrunfile])).to eq(YAML.dump("summary"))
    end

    it "should log but not fail if saving the last run summary fails" do
      # The mock will raise an exception on any method used.  This should
      # simulate a nice hard failure from the underlying OS for us.
      fh = Class.new(Object) do
        def method_missing(*args)
          raise "failed to do #{args[0]}"
        end
      end.new

      Oregano::Util.expects(:replace_file).yields(fh)

      Oregano.expects(:err)
      expect { @configurer.save_last_run_summary(@report) }.to_not raise_error
    end

    it "should create the last run file with the correct mode" do
      Oregano.settings.setting(:lastrunfile).expects(:mode).returns('664')
      @configurer.save_last_run_summary(@report)

      if Oregano::Util::Platform.windows?
        require 'oregano/util/windows/security'
        mode = Oregano::Util::Windows::Security.get_mode(Oregano[:lastrunfile])
      else
        mode = Oregano::FileSystem.stat(Oregano[:lastrunfile]).mode
      end
      expect(mode & 0777).to eq(0664)
    end

    it "should report invalid last run file permissions" do
      Oregano.settings.setting(:lastrunfile).expects(:mode).returns('892')
      Oregano.expects(:err).with(regexp_matches(/Could not save last run local report.*892 is invalid/))
      @configurer.save_last_run_summary(@report)
    end
  end

  describe "when requesting a node" do
    it "uses the transaction uuid in the request" do
      Oregano::Node.indirection.expects(:find).with(anything, has_entries(:transaction_uuid => anything)).twice
      @agent.run
    end

    it "sends an explicitly configured environment request" do
      Oregano.settings.expects(:set_by_config?).with(:environment).returns(true)
      Oregano::Node.indirection.expects(:find).with(anything, has_entries(:configured_environment => Oregano[:environment])).twice
      @agent.run
    end

    it "does not send a configured_environment when using the default" do
      Oregano::Node.indirection.expects(:find).with(anything, has_entries(:configured_environment => nil)).twice
      @agent.run
    end
  end

  def expects_new_catalog_only(catalog)
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns catalog
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.never
  end

  def expects_cached_catalog_only(catalog)
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns catalog
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.never
  end

  def expects_fallback_to_cached_catalog(catalog)
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns catalog
  end

  def expects_fallback_to_new_catalog(catalog)
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns nil
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns catalog
  end

  def expects_neither_new_or_cached_catalog
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil
    Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns nil
  end

  describe "when retrieving a catalog" do
    before do
      Oregano.settings.stubs(:use).returns(true)
      @agent.stubs(:facts_for_uploading).returns({})
      @agent.stubs(:download_plugins)

      # retrieve a catalog in the current environment, so we don't try to converge unexpectedly
      @catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote(Oregano[:environment].to_sym))

      # this is the default when using a Configurer instance
      Oregano::Resource::Catalog.indirection.stubs(:terminus_class).returns :rest
    end

    describe "and configured to only retrieve a catalog from the cache" do
      before do
        Oregano.settings[:use_cached_catalog] = true
      end

      it "should first look in the cache for a catalog" do
        expects_cached_catalog_only(@catalog)

        expect(@agent.retrieve_catalog({})).to eq(@catalog)
      end

      it "should not make a node request or pluginsync when a cached catalog is successfully retrieved" do
        Oregano::Node.indirection.expects(:find).never
        expects_cached_catalog_only(@catalog)
        @agent.expects(:download_plugins).never

        @agent.run
      end

      it "should make a node request and pluginsync when a cached catalog cannot be retrieved" do
        Oregano::Node.indirection.expects(:find).returns nil
        expects_fallback_to_new_catalog(@catalog)
        @agent.expects(:download_plugins)

        @agent.run
      end

      it "should set its cached_catalog_status to 'explicitly_requested'" do
        expects_cached_catalog_only(@catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('explicitly_requested')
      end

      it "should set its cached_catalog_status to 'explicitly requested' if the cached catalog is from a different environment" do
        cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('explicitly_requested')
      end

      it "should compile a new catalog if none is found in the cache" do
        expects_fallback_to_new_catalog(@catalog)

        expect(@agent.retrieve_catalog({})).to eq(@catalog)
      end

      it "should set its cached_catalog_status to 'not_used' if no catalog is found in the cache" do
        expects_fallback_to_new_catalog(@catalog)

        @agent.retrieve_catalog({})
        expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
      end

      it "should not attempt to retrieve a cached catalog again if the first attempt failed" do
        Oregano::Node.indirection.expects(:find).returns(nil)
        expects_neither_new_or_cached_catalog

        @agent.run
      end

      it "should return the cached catalog when the environment doesn't match" do
        cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote('second_env'))
        expects_cached_catalog_only(cached_catalog)

        Oregano.expects(:info).with("Using cached catalog from environment 'second_env'")
        expect(@agent.retrieve_catalog({})).to eq(cached_catalog)
      end
    end

    describe "and strict environment mode is set" do
      before do
        @catalog.stubs(:to_ral).returns(@catalog)
        @catalog.stubs(:write_class_file)
        @catalog.stubs(:write_resource_file)
        @agent.stubs(:send_report)
        @agent.stubs(:save_last_run_summary)
        Oregano.settings[:strict_environment_mode] = true
      end

      it "should not make a node request" do
        Oregano::Node.indirection.expects(:find).never

        @agent.run
      end

      it "should return nil when the catalog's environment doesn't match the agent specified environment" do
        @agent.instance_variable_set(:@environment, 'second_env')
        expects_new_catalog_only(@catalog)

        Oregano.expects(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
        expect(@agent.run).to be_nil
      end

      it "should not return nil when the catalog's environment matches the agent specified environment" do
        @agent.instance_variable_set(:@environment, 'production')
        expects_new_catalog_only(@catalog)

        expect(@agent.run).to eq(0)
      end

      describe "and a cached catalog is explicitly requested" do
        before do
          Oregano.settings[:use_cached_catalog] = true
        end

        it "should return nil when the cached catalog's environment doesn't match the agent specified environment" do
          @agent.instance_variable_set(:@environment, 'second_env')
          expects_cached_catalog_only(@catalog)

          Oregano.expects(:err).with("Not using catalog because its environment 'production' does not match agent specified environment 'second_env' and strict_environment_mode is set")
          expect(@agent.run).to be_nil
        end

        it "should proceed with the cached catalog if its environment matchs the local environment" do
          Oregano.settings[:use_cached_catalog] = true
          @agent.instance_variable_set(:@environment, 'production')
          expects_cached_catalog_only(@catalog)

          expect(@agent.run).to eq(0)
        end
      end
    end

    it "should use the Catalog class to get its catalog" do
      Oregano::Resource::Catalog.indirection.expects(:find).returns @catalog

      @agent.retrieve_catalog({})
    end

    it "should set its cached_catalog_status to 'not_used' when downloading a new catalog" do
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should use its node_name_value to retrieve the catalog" do
      Facter.stubs(:value).returns "eh"
      Oregano.settings[:node_name_value] = "myhost.domain.com"
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| name == "myhost.domain.com" }.returns @catalog

      @agent.retrieve_catalog({})
    end

    it "should default to returning a catalog retrieved directly from the server, skipping the cache" do
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns @catalog

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should log and return the cached catalog when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(@catalog)

      Oregano.expects(:info).with("Using cached catalog from environment 'production'")
      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' when no catalog can be retrieved from the server" do
      expects_fallback_to_cached_catalog(@catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end

    it "should not look in the cache for a catalog if one is returned from the server" do
      expects_new_catalog_only(@catalog)

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should return the cached catalog when retrieving the remote catalog throws an exception" do
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.raises "eh"
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

      expect(@agent.retrieve_catalog({})).to eq(@catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' when retrieving the remote catalog throws an exception" do
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.raises "eh"
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_terminus] == true }.returns @catalog

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end

    it "should log and return nil if no catalog can be retrieved from the server and :usecacheonfailure is disabled" do
      Oregano[:usecacheonfailure] = false
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil

      Oregano.expects(:warning).with('Not using cache on failed catalog')

      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if no catalog can be retrieved from the server and :usecacheonfailure is disabled or fails to retrieve a catalog" do
      Oregano[:usecacheonfailure] = false
      Oregano::Resource::Catalog.indirection.expects(:find).with { |name, options| options[:ignore_cache] == true }.returns nil

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should return nil if no cached catalog is available and no catalog can be retrieved from the server" do
      expects_neither_new_or_cached_catalog

      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should return nil if its cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote('second_env'))
      @agent.instance_variable_set(:@node_environment, 'production')

      expects_fallback_to_cached_catalog(cached_catalog)

      Oregano.expects(:err).with("Not using cached catalog because its environment 'second_env' does not match 'production'")
      expect(@agent.retrieve_catalog({})).to be_nil
    end

    it "should set its cached_catalog_status to 'not_used' if the cached catalog environment doesn't match server-specified environment" do
      cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote('second_env'))
      @agent.instance_variable_set(:@node_environment, 'production')

      expects_fallback_to_cached_catalog(cached_catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('not_used')
    end

    it "should return its cached catalog if the environment matches the server-specified environment" do
      cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote(Oregano[:environment]))
      @agent.instance_variable_set(:@node_environment, cached_catalog.environment)

      expects_fallback_to_cached_catalog(cached_catalog)

      expect(@agent.retrieve_catalog({})).to eq(cached_catalog)
    end

    it "should set its cached_catalog_status to 'on_failure' if the cached catalog environment matches server-specified environment" do
      cached_catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote(Oregano[:environment]))
      @agent.instance_variable_set(:@node_environment, cached_catalog.environment)

      expects_fallback_to_cached_catalog(cached_catalog)

      @agent.retrieve_catalog({})
      expect(@agent.instance_variable_get(:@cached_catalog_status)).to eq('on_failure')
    end
  end

  describe "when converting the catalog" do
    before do
      Oregano.settings.stubs(:use).returns(true)

      catalog.stubs(:to_ral).returns ral_catalog
    end

    let (:catalog) { Oregano::Resource::Catalog.new('tester', Oregano::Node::Environment.remote(Oregano[:environment].to_sym)) }
    let (:ral_catalog) { Oregano::Resource::Catalog.new('tester', Oregano::Node::Environment.remote(Oregano[:environment].to_sym)) }

    it "should convert the catalog to a RAL-formed catalog" do
      expect(@agent.convert_catalog(catalog, 10)).to equal(ral_catalog)
    end

    it "should finalize the catalog" do
      ral_catalog.expects(:finalize)

      @agent.convert_catalog(catalog, 10)
    end

    it "should record the passed retrieval time with the RAL catalog" do
      ral_catalog.expects(:retrieval_duration=).with 10

      @agent.convert_catalog(catalog, 10)
    end

    it "should write the RAL catalog's class file" do
      ral_catalog.expects(:write_class_file)

      @agent.convert_catalog(catalog, 10)
    end

    it "should write the RAL catalog's resource file" do
      ral_catalog.expects(:write_resource_file)

      @agent.convert_catalog(catalog, 10)
    end
  end

  describe "when determining whether to pluginsync" do
    it "should default to Oregano[:pluginsync] when explicitly set by the commandline" do
      Oregano.settings[:pluginsync] = false
      Oregano.settings.expects(:set_by_cli?).returns(true)

      expect(described_class).not_to be_should_pluginsync
    end

    it "should default to Oregano[:pluginsync] when explicitly set by config" do
      Oregano.settings[:pluginsync] = false
      Oregano.settings.expects(:set_by_config?).returns(true)

      expect(described_class).not_to be_should_pluginsync
    end

    it "should be true if use_cached_catalog is false" do
      Oregano.settings[:use_cached_catalog] = false

      expect(described_class).to be_should_pluginsync
    end

    it "should be false if use_cached_catalog is true" do
      Oregano.settings[:use_cached_catalog] = true

      expect(described_class).not_to be_should_pluginsync
    end
  end

  describe "when attempting failover" do
    it "should not failover if server_list is not set" do
      Oregano.settings[:server_list] = []
      @agent.expects(:find_functional_server).never
      @agent.run
    end

    it "should not failover during an apply run" do
      Oregano.settings[:server_list] = ["myserver:123"]
      @agent.expects(:find_functional_server).never
      catalog = Oregano::Resource::Catalog.new("tester", Oregano::Node::Environment.remote(Oregano[:environment].to_sym))
      @agent.run :catalog => catalog
    end

    it "should select a server when provided" do
      Oregano.settings[:server_list] = ["myserver:123"]
      pool = Oregano::Network::HTTP::Pool.new(Oregano[:http_keepalive_timeout])
      Oregano::Network::HTTP::Pool.expects(:new).returns(pool)
      Oregano.expects(:override).with({:http_pool => pool}).yields
      Oregano.expects(:override).with({:server => "myserver", :serverport => '123'}).twice.yields
      Oregano::Node.indirection.expects(:find).returns(nil)
      @agent.expects(:run_internal).returns(nil)
      @agent.run
    end

    it "should fallback to an empty server when failover fails" do
      Oregano.settings[:server_list] = ["myserver:123"]
      pool = Oregano::Network::HTTP::Pool.new(Oregano[:http_keepalive_timeout])
      Oregano::Network::HTTP::Pool.expects(:new).returns(pool)
      Oregano.expects(:override).with({:http_pool => pool}).yields
      Oregano.expects(:override).with({:server => "myserver", :serverport => '123'}).yields
      Oregano.expects(:override).with({:server => nil, :serverport => nil}).yields
      error = Net::HTTPError.new(400, 'dummy server communication error')
      Oregano::Node.indirection.expects(:find).raises(error)
      @agent.expects(:run_internal).returns(nil)
      @agent.run
    end

    it "should not make multiple node requets when the server is found" do
      Oregano.settings[:server_list] = ["myserver:123"]
      Oregano::Node.indirection.expects(:find).returns("mynode").once
      @agent.expects(:prepare_and_retrieve_catalog).returns(nil)
      @agent.run
    end
  end
end
