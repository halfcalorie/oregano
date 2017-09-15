#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/application/master'
require 'oregano/daemon'
require 'oregano/network/server'

describe Oregano::Application::Master, :unless => Oregano.features.microsoft_windows? do
  before :each do
    @master = Oregano::Application[:master]
    @daemon = stub_everything 'daemon'
    Oregano::Daemon.stubs(:new).returns(@daemon)
    Oregano::Util::Log.stubs(:newdestination)

    Oregano::Node.indirection.stubs(:terminus_class=)
    Oregano::Node::Facts.indirection.stubs(:terminus_class=)
    Oregano::Node::Facts.indirection.stubs(:cache_class=)
    Oregano::Transaction::Report.indirection.stubs(:terminus_class=)
    Oregano::Resource::Catalog.indirection.stubs(:terminus_class=)
    Oregano::SSL::Host.stubs(:ca_location=)
  end

  it "should operate in master run_mode" do
    expect(@master.class.run_mode.name).to equal(:master)
  end

  it "should declare a main command" do
    expect(@master).to respond_to(:main)
  end

  it "should declare a compile command" do
    expect(@master).to respond_to(:compile)
  end

  it "should declare a preinit block" do
    expect(@master).to respond_to(:preinit)
  end

  describe "during preinit" do
    before :each do
      @master.stubs(:trap)
    end

    it "should catch INT" do
      @master.stubs(:trap).with { |arg,block| arg == :INT }

      @master.preinit
    end
  end

  [:debug,:verbose].each do |option|
    it "should declare handle_#{option} method" do
      expect(@master).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @master.options.expects(:[]=).with(option, 'arg')
      @master.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "when applying options" do
    before do
      @master.command_line.stubs(:args).returns([])
    end

    it "should set the log destination with --logdest" do
      Oregano::Log.expects(:newdestination).with("console")

      @master.handle_logdest("console")
    end

    it "should put the setdest options to true" do
      @master.options.expects(:[]=).with(:setdest,true)

      @master.handle_logdest("console")
    end

    it "should parse the log destination from ARGV" do
      @master.command_line.stubs(:args).returns(%w{--logdest /my/file})

      Oregano::Util::Log.expects(:newdestination).with("/my/file")

      @master.parse_options
    end

    it "should support dns alt names from ARGV" do
      Oregano.settings.initialize_global_settings(["--dns_alt_names", "foo,bar,baz"])

      @master.preinit
      @master.parse_options

      expect(Oregano[:dns_alt_names]).to eq("foo,bar,baz")
    end


  end

  describe "during setup" do
    before :each do
      Oregano::Log.stubs(:newdestination)
      Oregano.stubs(:settraps)
      Oregano::SSL::CertificateAuthority.stubs(:instance)
      Oregano::SSL::CertificateAuthority.stubs(:ca?)
      Oregano.settings.stubs(:use)

      @master.options.stubs(:[]).with(any_parameters)
    end

    it "should abort stating that the master is not supported on Windows" do
      Oregano.features.stubs(:microsoft_windows?).returns(true)

      expect { @master.setup }.to raise_error(Oregano::Error, /Oregano master is not supported on Microsoft Windows/)
    end

    describe "setting up logging" do
      it "sets the log level" do
        @master.expects(:set_log_level)
        @master.setup
      end

      describe "when the log destination is not explicitly configured" do
        before do
          @master.options.stubs(:[]).with(:setdest).returns false
        end

        it "logs to the console when --compile is given" do
          @master.options.stubs(:[]).with(:node).returns "default"
          Oregano::Util::Log.expects(:newdestination).with(:console)
          @master.setup
        end

        it "logs to the console when the master is not daemonized or run with rack" do
          Oregano::Util::Log.expects(:newdestination).with(:console)
          Oregano[:daemonize] = false
          @master.options.stubs(:[]).with(:rack).returns(false)
          @master.setup
        end

        it "logs to syslog when the master is daemonized" do
          Oregano::Util::Log.expects(:newdestination).with(:console).never
          Oregano::Util::Log.expects(:newdestination).with(:syslog)
          Oregano[:daemonize] = true
          @master.options.stubs(:[]).with(:rack).returns(false)
          @master.setup
        end

        it "logs to syslog when the master is run with rack" do
          Oregano::Util::Log.expects(:newdestination).with(:console).never
          Oregano::Util::Log.expects(:newdestination).with(:syslog)
          Oregano[:daemonize] = false
          @master.options.stubs(:[]).with(:rack).returns(true)
          @master.setup
        end
      end
    end

    it "should print oregano config if asked to in Oregano config" do
      Oregano.settings.stubs(:print_configs?).returns(true)
      Oregano.settings.expects(:print_configs).returns(true)
      expect { @master.setup }.to exit_with 0
    end

    it "should exit after printing oregano config if asked to in Oregano config" do
      Oregano.settings.stubs(:print_configs?).returns(true)
      expect { @master.setup }.to exit_with 1
    end

    it "should tell Oregano.settings to use :main,:ssl,:master and :metrics category" do
      Oregano.settings.expects(:use).with(:main,:master,:ssl,:metrics)

      @master.setup
    end

    describe "with no ca" do

      it "should set the ca_location to none" do
        Oregano::SSL::Host.expects(:ca_location=).with(:none)

        @master.setup
      end

    end

    describe "with a ca configured" do

      before :each do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(true)
      end

      it "should set the ca_location to local" do
        Oregano::SSL::Host.expects(:ca_location=).with(:local)

        @master.setup
      end

      it "should tell Oregano.settings to use :ca category" do
        Oregano.settings.expects(:use).with(:ca)

        @master.setup
      end

      it "should instantiate the CertificateAuthority singleton" do
        Oregano::SSL::CertificateAuthority.expects(:instance)

        @master.setup
      end
    end

    it "should not set Oregano[:node_cache_terminus] by default" do
      # This is normally called early in the application lifecycle but in our
      # spec testing we don't actually do a full application initialization so
      # we call it here to validate the (possibly) overridden settings are as we
      # expect
      @master.initialize_app_defaults
      @master.setup

      expect(Oregano[:node_cache_terminus]).to be(nil)
    end

    it "should honor Oregano[:node_cache_terminus] by setting the cache_class to its value" do
      # PUP-6060 - ensure we honor this value if specified
      @master.initialize_app_defaults
      Oregano[:node_cache_terminus] = 'plain'
      @master.setup

      expect(Oregano::Node.indirection.cache_class).to eq(:plain)
    end
  end

  describe "when running" do
    before do
      @master.preinit
    end

    it "should dispatch to compile if called with --compile" do
      @master.options[:node] = "foo"
      @master.expects(:compile)
      @master.run_command
    end

    it "should dispatch to main otherwise" do
      @master.options[:node] = nil

      @master.expects(:main)
      @master.run_command
    end

    describe "the compile command" do
      before do
        Oregano[:manifest] = "site.pp"
        Oregano.stubs(:err)
        @master.stubs(:puts)
      end

      it "should compile a catalog for the specified node" do
        @master.options[:node] = "foo"
        Oregano::Resource::Catalog.indirection.expects(:find).with("foo").returns Oregano::Resource::Catalog.new

        expect { @master.compile }.to exit_with 0
      end

      it "should convert the catalog to a pure-resource catalog and use 'JSON::pretty_generate' to pretty-print the catalog" do
        catalog = Oregano::Resource::Catalog.new
        JSON.stubs(:pretty_generate)
        Oregano::Resource::Catalog.indirection.expects(:find).returns catalog

        catalog.expects(:to_resource).returns("rescat")

        @master.options[:node] = "foo"
        JSON.expects(:pretty_generate).with('rescat', :allow_nan => true, :max_nesting => false)

        expect { @master.compile }.to exit_with 0
      end

      it "should exit with error code 30 if no catalog can be found" do
        @master.options[:node] = "foo"
        Oregano::Resource::Catalog.indirection.expects(:find).returns nil
        Oregano.expects(:log_exception)
        expect { @master.compile }.to exit_with 30
      end

      it "should exit with error code 30 if there's a failure" do
        @master.options[:node] = "foo"
        Oregano::Resource::Catalog.indirection.expects(:find).raises ArgumentError
        Oregano.expects(:log_exception)
        expect { @master.compile }.to exit_with 30
      end
    end

    describe "the main command" do
      before :each do
        @master.preinit
        @server = stub_everything 'server'
        Oregano::Network::Server.stubs(:new).returns(@server)
        @app = stub_everything 'app'
        Oregano::SSL::Host.stubs(:localhost)
        Oregano::SSL::CertificateAuthority.stubs(:ca?)
        Process.stubs(:uid).returns(1000)
        Oregano.stubs(:service)
        Oregano[:daemonize] = false
        Oregano.stubs(:notice)
        Oregano.stubs(:start)
        Oregano::Util.stubs(:chuser)
      end

      it "should create a Server" do
        Oregano::Network::Server.expects(:new)

        @master.main
      end

      it "should give the server to the daemon" do
        @daemon.expects(:server=).with(@server)

        @master.main
      end

      it "should generate a SSL cert for localhost" do
        Oregano::SSL::Host.expects(:localhost)

        @master.main
      end

      it "should make sure to *only* hit the CA for data" do
        Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(true)

        Oregano::SSL::Host.expects(:ca_location=).with(:only)

        @master.main
      end

      def a_user_type_for(username)
        user = mock 'user'
        Oregano::Type.type(:user).expects(:new).with { |args| args[:name] == username }.returns user
        user
      end

      context "user privileges" do
        it "should drop privileges if running as root and the oregano user exists" do
          Oregano.features.stubs(:root?).returns true
          a_user_type_for("oregano").expects(:exists?).returns true

          Oregano::Util.expects(:chuser)

          @master.main
        end

        it "should exit and log an error if running as root and the oregano user does not exist" do
          Oregano.features.stubs(:root?).returns true
          a_user_type_for("oregano").expects(:exists?).returns false
          Oregano.expects(:err).with('Could not change user to oregano. User does not exist and is required to continue.')
          expect { @master.main }.to exit_with 74
        end
      end

      it "should log a deprecation notice when running a WEBrick server" do
        Oregano.expects(:deprecation_warning).with("The WEBrick Oregano master server is deprecated and will be removed in a future release. Please use Oregano Server instead. See http://links.oregano.com/deprecate-rack-webrick-servers for more information.")

        @master.main
      end

      it "should daemonize if needed" do
        Oregano[:daemonize] = true

        @daemon.expects(:daemonize)

        @master.main
      end

      it "should start the service" do
        @daemon.expects(:start)

        @master.main
      end

      describe "with --rack", :if => Oregano.features.rack? do
        before do
          require 'oregano/network/http/rack'
          Oregano::Network::HTTP::Rack.stubs(:new).returns(@app)

          @master.options.stubs(:[]).with(:rack).returns(:true)
        end

        it "it should not start a daemon" do
          @daemon.expects(:start).never

          @master.main
        end

        it "it should return the app" do
          app = @master.main
          expect(app).to equal(@app)
        end

        it "should log a deprecation notice" do
          Oregano.expects(:deprecation_warning).with("The Rack Oregano master server is deprecated and will be removed in a future release. Please use Oregano Server instead. See http://links.oregano.com/deprecate-rack-webrick-servers for more information.")

          @master.main
        end
      end
    end
  end
end
