#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/agent'
require 'oregano/application/agent'
require 'oregano/network/server'
require 'oregano/daemon'

describe Oregano::Application::Agent do
  include OreganoSpec::Files

  before :each do
    @oreganod = Oregano::Application[:agent]

    @daemon = Oregano::Daemon.new(nil)
    @daemon.stubs(:daemonize)
    @daemon.stubs(:start)
    @daemon.stubs(:stop)
    Oregano::Daemon.stubs(:new).returns(@daemon)
    Oregano[:daemonize] = false

    @agent = stub_everything 'agent'
    Oregano::Agent.stubs(:new).returns(@agent)

    @oreganod.preinit
    Oregano::Util::Log.stubs(:newdestination)

    @ssl_host = stub_everything 'ssl host'
    Oregano::SSL::Host.stubs(:new).returns(@ssl_host)

    Oregano::Node.indirection.stubs(:terminus_class=)
    Oregano::Node.indirection.stubs(:cache_class=)
    Oregano::Node::Facts.indirection.stubs(:terminus_class=)

    $stderr.expects(:puts).never

    Oregano.settings.stubs(:use)
  end

  it "should operate in agent run_mode" do
    expect(@oreganod.class.run_mode.name).to eq(:agent)
  end

  it "should declare a main command" do
    expect(@oreganod).to respond_to(:main)
  end

  it "should declare a onetime command" do
    expect(@oreganod).to respond_to(:onetime)
  end

  it "should declare a fingerprint command" do
    expect(@oreganod).to respond_to(:fingerprint)
  end

  it "should declare a preinit block" do
    expect(@oreganod).to respond_to(:preinit)
  end

  describe "in preinit" do
    it "should catch INT" do
      Signal.expects(:trap).with { |arg,block| arg == :INT }

      @oreganod.preinit
    end

    it "should init fqdn to nil" do
      @oreganod.preinit

      expect(@oreganod.options[:fqdn]).to be_nil
    end

    it "should init serve to []" do
      @oreganod.preinit

      expect(@oreganod.options[:serve]).to eq([])
    end

    it "should use SHA256 as default digest algorithm" do
      @oreganod.preinit

      expect(@oreganod.options[:digest]).to eq('SHA256')
    end

    it "should not fingerprint by default" do
      @oreganod.preinit

      expect(@oreganod.options[:fingerprint]).to be_falsey
    end

    it "should init waitforcert to nil" do
      @oreganod.preinit

      expect(@oreganod.options[:waitforcert]).to be_nil
    end
  end

  describe "when handling options" do
    before do
      @oreganod.command_line.stubs(:args).returns([])
    end

    [:enable, :debug, :fqdn, :test, :verbose, :digest].each do |option|
      it "should declare handle_#{option} method" do
        expect(@oreganod).to respond_to("handle_#{option}".to_sym)
      end

      it "should store argument value when calling handle_#{option}" do
        @oreganod.send("handle_#{option}".to_sym, 'arg')

        expect(@oreganod.options[option]).to eq('arg')
      end
    end

    describe "when handling --disable" do
      it "should set disable to true" do
        @oreganod.handle_disable('')

        expect(@oreganod.options[:disable]).to eq(true)
      end

      it "should store disable message" do
        @oreganod.handle_disable('message')

        expect(@oreganod.options[:disable_message]).to eq('message')
      end
    end

    it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
      @agent.stubs(:run).returns(2)
      Oregano[:onetime] = true

      @ssl_host.expects(:wait_for_cert).with(0)

      expect { execute_agent }.to exit_with 0
    end

    it "should use supplied waitforcert when --onetime is specified" do
      @agent.stubs(:run).returns(2)
      Oregano[:onetime] = true
      @oreganod.handle_waitforcert(60)

      @ssl_host.expects(:wait_for_cert).with(60)

      expect { execute_agent }.to exit_with 0
    end

    it "should use a default value for waitforcert when --onetime and --waitforcert are not specified" do
      @ssl_host.expects(:wait_for_cert).with(120)

      execute_agent
    end

    it "should use the waitforcert setting when checking for a signed certificate" do
      Oregano[:waitforcert] = 10
      @ssl_host.expects(:wait_for_cert).with(10)

      execute_agent
    end

    it "should set the log destination with --logdest" do
      Oregano::Log.expects(:newdestination).with("console")

      @oreganod.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @oreganod.handle_logdest("console")

      expect(@oreganod.options[:setdest]).to eq(true)
    end

    it "should parse the log destination from the command line" do
      @oreganod.command_line.stubs(:args).returns(%w{--logdest /my/file})

      Oregano::Util::Log.expects(:newdestination).with("/my/file")

      @oreganod.parse_options
    end

    it "should store the waitforcert options with --waitforcert" do
      @oreganod.handle_waitforcert("42")

      expect(@oreganod.options[:waitforcert]).to eq(42)
    end
  end

  describe "during setup" do
    before :each do
      Oregano.stubs(:info)
      Oregano[:libdir] = "/dev/null/lib"
      Oregano::Transaction::Report.indirection.stubs(:terminus_class=)
      Oregano::Transaction::Report.indirection.stubs(:cache_class=)
      Oregano::Resource::Catalog.indirection.stubs(:terminus_class=)
      Oregano::Resource::Catalog.indirection.stubs(:cache_class=)
      Oregano::Node::Facts.indirection.stubs(:terminus_class=)
      Oregano.stubs(:settraps)
    end

    it "should not run with extra arguments" do
      @oreganod.command_line.stubs(:args).returns(%w{disable})
      expect{@oreganod.setup}.to raise_error ArgumentError, /does not take parameters/
    end

    describe "with --test" do
      it "should call setup_test" do
        @oreganod.options[:test] = true
        @oreganod.expects(:setup_test)

        @oreganod.setup
      end

      it "should set options[:verbose] to true" do
        @oreganod.setup_test

        expect(@oreganod.options[:verbose]).to eq(true)
      end
      it "should set options[:onetime] to true" do
        Oregano[:onetime] = false
        @oreganod.setup_test
        expect(Oregano[:onetime]).to eq(true)
      end
      it "should set options[:detailed_exitcodes] to true" do
        @oreganod.setup_test

        expect(@oreganod.options[:detailed_exitcodes]).to eq(true)
      end
    end

    it "should call setup_logs" do
      @oreganod.expects(:setup_logs)
      @oreganod.setup
    end

    describe "when setting up logs" do
      before :each do
        Oregano::Util::Log.stubs(:newdestination)
      end

      it "should set log level to debug if --debug was passed" do
        @oreganod.options[:debug] = true
        @oreganod.setup_logs
        expect(Oregano::Util::Log.level).to eq(:debug)
      end

      it "should set log level to info if --verbose was passed" do
        @oreganod.options[:verbose] = true
        @oreganod.setup_logs
        expect(Oregano::Util::Log.level).to eq(:info)
      end

      [:verbose, :debug].each do |level|
        it "should set console as the log destination with level #{level}" do
          @oreganod.options[level] = true

          Oregano::Util::Log.expects(:newdestination).at_least_once
          Oregano::Util::Log.expects(:newdestination).with(:console).once

          @oreganod.setup_logs
        end
      end

      it "should set a default log destination if no --logdest" do
        @oreganod.options[:setdest] = false

        Oregano::Util::Log.expects(:setup_default)

        @oreganod.setup_logs
      end

    end

    it "should print oregano config if asked to in Oregano config" do
      Oregano[:configprint] = "pluginsync"
      Oregano.settings.expects(:print_configs).returns true
      expect { execute_agent }.to exit_with 0
    end

    it "should exit after printing oregano config if asked to in Oregano config" do
      path = make_absolute('/my/path')
      Oregano[:modulepath] = path
      Oregano[:configprint] = "modulepath"
      Oregano::Settings.any_instance.expects(:puts).with(path)
      expect { execute_agent }.to exit_with 0
    end

    it "should use :main, :oreganod, and :ssl" do
      Oregano.settings.unstub(:use)
      Oregano.settings.expects(:use).with(:main, :agent, :ssl)

      @oreganod.setup
    end

    it "should install a remote ca location" do
      Oregano::SSL::Host.expects(:ca_location=).with(:remote)

      @oreganod.setup
    end

    it "should install a none ca location in fingerprint mode" do
      @oreganod.options[:fingerprint] = true
      Oregano::SSL::Host.expects(:ca_location=).with(:none)

      @oreganod.setup
    end

    it "should tell the report handler to use REST" do
      Oregano::Transaction::Report.indirection.expects(:terminus_class=).with(:rest)

      @oreganod.setup
    end

    it "should tell the report handler to cache locally as yaml" do
      Oregano::Transaction::Report.indirection.expects(:cache_class=).with(:yaml)

      @oreganod.setup
    end

    it "should default catalog_terminus setting to 'rest'" do
      @oreganod.initialize_app_defaults
      expect(Oregano[:catalog_terminus]).to eq(:rest)
    end

    it "should default node_terminus setting to 'rest'" do
      @oreganod.initialize_app_defaults
      expect(Oregano[:node_terminus]).to eq(:rest)
    end

    it "has an application default :catalog_cache_terminus setting of 'json'" do
      Oregano::Resource::Catalog.indirection.expects(:cache_class=).with(:json)

      @oreganod.initialize_app_defaults
      @oreganod.setup
    end

    it "should tell the catalog cache class based on the :catalog_cache_terminus setting" do
      Oregano[:catalog_cache_terminus] = "yaml"
      Oregano::Resource::Catalog.indirection.expects(:cache_class=).with(:yaml)

      @oreganod.initialize_app_defaults
      @oreganod.setup
    end

    it "should not set catalog cache class if :catalog_cache_terminus is explicitly nil" do
      Oregano[:catalog_cache_terminus] = nil
      Oregano::Resource::Catalog.indirection.unstub(:cache_class=)
      Oregano::Resource::Catalog.indirection.expects(:cache_class=).never

      @oreganod.initialize_app_defaults
      @oreganod.setup
    end

    it "should set catalog cache class to nil during a noop run" do
      Oregano[:catalog_cache_terminus] = "json"
      Oregano[:noop] = true
      Oregano::Resource::Catalog.indirection.expects(:cache_class=).with(nil)

      @oreganod.initialize_app_defaults
      @oreganod.setup
    end

    it "should default facts_terminus setting to 'facter'" do
      @oreganod.initialize_app_defaults
      expect(Oregano[:facts_terminus]).to eq(:facter)
    end

    it "should create an agent" do
      Oregano::Agent.stubs(:new).with(Oregano::Configurer)

      @oreganod.setup
    end

    [:enable, :disable].each do |action|
      it "should delegate to enable_disable_client if we #{action} the agent" do
        @oreganod.options[action] = true
        @oreganod.expects(:enable_disable_client).with(@agent)

        @oreganod.setup
      end
    end

    describe "when enabling or disabling agent" do
      [:enable, :disable].each do |action|
        it "should call client.#{action}" do
          @oreganod.options[action] = true
          @agent.expects(action)
          expect { execute_agent }.to exit_with 0
        end
      end

      it "should pass the disable message when disabling" do
        @oreganod.options[:disable] = true
        @oreganod.options[:disable_message] = "message"
        @agent.expects(:disable).with("message")

        expect { execute_agent }.to exit_with 0
      end

      it "should pass the default disable message when disabling without a message" do
        @oreganod.options[:disable] = true
        @oreganod.options[:disable_message] = nil
        @agent.expects(:disable).with("reason not specified")

        expect { execute_agent }.to exit_with 0
      end
    end

    it "should inform the daemon about our agent if :client is set to 'true'" do
      @oreganod.options[:client] = true

      execute_agent

      expect(@daemon.agent).to eq(@agent)
    end

    it "should daemonize if needed" do
      Oregano.features.stubs(:microsoft_windows?).returns false
      Oregano[:daemonize] = true

      @daemon.expects(:daemonize)

      execute_agent
    end

    it "should wait for a certificate" do
      @oreganod.options[:waitforcert] = 123
      @ssl_host.expects(:wait_for_cert).with(123)

      execute_agent
    end

    it "should not wait for a certificate in fingerprint mode" do
      @oreganod.options[:fingerprint] = true
      @oreganod.options[:waitforcert] = 123
      @oreganod.options[:digest] = 'MD5'

      certificate = mock 'certificate'
      certificate.stubs(:digest).with('MD5').returns('ABCDE')
      @ssl_host.stubs(:certificate).returns(certificate)

      @ssl_host.expects(:wait_for_cert).never
      @oreganod.expects(:puts).with('ABCDE')

      execute_agent
    end

    describe "when setting up for fingerprint" do
      before(:each) do
        @oreganod.options[:fingerprint] = true
      end

      it "should not setup as an agent" do
        @oreganod.expects(:setup_agent).never
        @oreganod.setup
      end

      it "should not create an agent" do
        Oregano::Agent.stubs(:new).with(Oregano::Configurer).never
        @oreganod.setup
      end

      it "should not daemonize" do
        @daemon.expects(:daemonize).never
        @oreganod.setup
      end
    end

    describe "when configuring agent for catalog run" do
      it "should set should_fork as true when running normally" do
        Oregano::Agent.expects(:new).with(anything, true)
        @oreganod.setup
      end

      it "should not set should_fork as false for --onetime" do
        Oregano[:onetime] = true
        Oregano::Agent.expects(:new).with(anything, false)
        @oreganod.setup
      end
    end
  end


  describe "when running" do
    before :each do
      @oreganod.options[:fingerprint] = false
    end

    it "should dispatch to fingerprint if --fingerprint is used" do
      @oreganod.options[:fingerprint] = true

      @oreganod.stubs(:fingerprint)

      execute_agent
    end

    it "should dispatch to onetime if --onetime is used" do
      @oreganod.options[:onetime] = true

      @oreganod.stubs(:onetime)

      execute_agent
    end

    it "should dispatch to main if --onetime and --fingerprint are not used" do
      @oreganod.options[:onetime] = false

      @oreganod.stubs(:main)

      execute_agent
    end

    describe "with --onetime" do

      before :each do
        @agent.stubs(:run).returns(:report)
        Oregano[:onetime] = true
        @oreganod.options[:client] = :client
        @oreganod.options[:detailed_exitcodes] = false
      end

      it "should setup traps" do
        @daemon.expects(:set_signal_traps)

        expect { execute_agent }.to exit_with 0
      end

      it "should let the agent run" do
        @agent.expects(:run).returns(:report)

        expect { execute_agent }.to exit_with 0
      end

      it "should run the agent with the supplied job_id" do
        @oreganod.options[:job_id] = 'special id'
        @agent.expects(:run).with(:job_id => 'special id').returns(:report)

        expect { execute_agent }.to exit_with 0
      end

      it "should stop the daemon" do
        @daemon.expects(:stop).with(:exit => false)

        expect { execute_agent }.to exit_with 0
      end

      describe "and --detailed-exitcodes" do
        before :each do
          @oreganod.options[:detailed_exitcodes] = true
        end

        it "should exit with agent computed exit status" do
          Oregano[:noop] = false
          @agent.stubs(:run).returns(666)

          expect { execute_agent }.to exit_with 666
        end

        it "should exit with the agent's exit status, even if --noop is set." do
          Oregano[:noop] = true
          @agent.stubs(:run).returns(666)

          expect { execute_agent }.to exit_with 666
        end
      end
    end

    describe "with --fingerprint" do
      before :each do
        @cert = mock 'cert'
        @oreganod.options[:fingerprint] = true
        @oreganod.options[:digest] = :MD5
      end

      it "should fingerprint the certificate if it exists" do
        @ssl_host.stubs(:certificate).returns(@cert)
        @cert.stubs(:digest).with('MD5').returns "fingerprint"

        @oreganod.expects(:puts).with "fingerprint"

        @oreganod.fingerprint
      end

      it "should fingerprint the certificate request if no certificate have been signed" do
        @ssl_host.stubs(:certificate).returns(nil)
        @ssl_host.stubs(:certificate_request).returns(@cert)
        @cert.stubs(:digest).with('MD5').returns "fingerprint"

        @oreganod.expects(:puts).with "fingerprint"

        @oreganod.fingerprint
      end
    end

    describe "without --onetime and --fingerprint" do
      before :each do
        Oregano.stubs(:notice)
      end

      it "should start our daemon" do
        @daemon.expects(:start)

        execute_agent
      end
    end
  end

  def execute_agent
    @oreganod.setup
    @oreganod.run_command
  end
end
