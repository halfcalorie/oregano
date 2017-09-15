#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/application/apply'
require 'oregano/file_bucket/dipper'
require 'oregano/configurer'
require 'fileutils'

describe Oregano::Application::Apply do
  before :each do
    @apply = Oregano::Application[:apply]
    Oregano::Util::Log.stubs(:newdestination)
    Oregano[:reports] = "none"
  end

  after :each do
    Oregano::Node::Facts.indirection.reset_terminus_class
    Oregano::Node::Facts.indirection.cache_class = nil

    Oregano::Node.indirection.reset_terminus_class
    Oregano::Node.indirection.cache_class = nil
  end

  [:debug,:loadclasses,:test,:verbose,:use_nodes,:detailed_exitcodes,:catalog, :write_catalog_summary].each do |option|
    it "should declare handle_#{option} method" do
      expect(@apply).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      @apply.options.expects(:[]=).with(option, 'arg')
      @apply.send("handle_#{option}".to_sym, 'arg')
    end
  end

  it "should set the code to the provided code when :execute is used" do
    @apply.options.expects(:[]=).with(:code, 'arg')
    @apply.send("handle_execute".to_sym, 'arg')
  end

  describe "when applying options" do

    it "should set the log destination with --logdest" do
      Oregano::Log.expects(:newdestination).with("console")

      @apply.handle_logdest("console")
    end

    it "should set the setdest options to true" do
      @apply.options.expects(:[]=).with(:setdest,true)

      @apply.handle_logdest("console")
    end
  end

  describe "during setup" do
    before :each do
      Oregano::Log.stubs(:newdestination)
      Oregano::FileBucket::Dipper.stubs(:new)
      STDIN.stubs(:read)
      Oregano::Transaction::Report.indirection.stubs(:cache_class=)
    end

    describe "with --test" do
      it "should call setup_test" do
        @apply.options[:test] = true
        @apply.expects(:setup_test)

        @apply.setup
      end

      it "should set options[:verbose] to true" do
        @apply.setup_test

        expect(@apply.options[:verbose]).to eq(true)
      end
      it "should set options[:show_diff] to true" do
        Oregano.settings.override_default(:show_diff, false)
        @apply.setup_test
        expect(Oregano[:show_diff]).to eq(true)
      end
      it "should set options[:detailed_exitcodes] to true" do
        @apply.setup_test

        expect(@apply.options[:detailed_exitcodes]).to eq(true)
      end
    end

    it "should set console as the log destination if logdest option wasn't provided" do
      Oregano::Log.expects(:newdestination).with(:console)

      @apply.setup
    end

    it "should set INT trap" do
      Signal.expects(:trap).with(:INT)

      @apply.setup
    end

    it "should set log level to debug if --debug was passed" do
      @apply.options[:debug] = true
      @apply.setup
      expect(Oregano::Log.level).to eq(:debug)
    end

    it "should set log level to info if --verbose was passed" do
      @apply.options[:verbose] = true
      @apply.setup
      expect(Oregano::Log.level).to eq(:info)
    end

    it "should print oregano config if asked to in Oregano config" do
      Oregano.settings.stubs(:print_configs?).returns  true
      Oregano.settings.expects(:print_configs).returns true
      expect { @apply.setup }.to exit_with 0
    end

    it "should exit after printing oregano config if asked to in Oregano config" do
      Oregano.settings.stubs(:print_configs?).returns(true)
      expect { @apply.setup }.to exit_with 1
    end

    it "should use :main, :oreganod, and :ssl" do
      Oregano.settings.unstub(:use)
      Oregano.settings.expects(:use).with(:main, :agent, :ssl)

      @apply.setup
    end

    it "should tell the report handler to cache locally as yaml" do
      Oregano::Transaction::Report.indirection.expects(:cache_class=).with(:yaml)

      @apply.setup
    end

    it "configures a profiler when profiling is enabled" do
      Oregano[:profile] = true

      @apply.setup

      expect(Oregano::Util::Profiler.current).to satisfy do |ps|
        ps.any? {|p| p.is_a? Oregano::Util::Profiler::WallClock }
      end
    end

    it "does not have a profiler if profiling is disabled" do
      Oregano[:profile] = false

      @apply.setup

      expect(Oregano::Util::Profiler.current.length).to be 0
    end

    it "should set default_file_terminus to `file_server` to be local" do
      expect(@apply.app_defaults[:default_file_terminus]).to eq(:file_server)
    end
  end

  describe "when executing" do
    it "should dispatch to 'apply' if it was called with 'apply'" do
      @apply.options[:catalog] = "foo"

      @apply.expects(:apply)
      @apply.run_command
    end

    it "should dispatch to main otherwise" do
      @apply.stubs(:options).returns({})

      @apply.expects(:main)
      @apply.run_command
    end

    describe "the main command" do
      include OreganoSpec::Files

      before :each do
        Oregano[:prerun_command] = ''
        Oregano[:postrun_command] = ''

        Oregano::Node::Facts.indirection.terminus_class = :memory
        Oregano::Node::Facts.indirection.cache_class = :memory
        Oregano::Node.indirection.terminus_class = :memory
        Oregano::Node.indirection.cache_class = :memory

        @facts = Oregano::Node::Facts.new(Oregano[:node_name_value])
        Oregano::Node::Facts.indirection.save(@facts)

        @node = Oregano::Node.new(Oregano[:node_name_value])
        Oregano::Node.indirection.save(@node)

        @catalog = Oregano::Resource::Catalog.new("testing", Oregano.lookup(:environments).get(Oregano[:environment]))
        @catalog.stubs(:to_ral).returns(@catalog)

        Oregano::Resource::Catalog.indirection.stubs(:find).returns(@catalog)

        STDIN.stubs(:read)

        @transaction = stub('transaction')
        @catalog.stubs(:apply).returns(@transaction)

        Oregano::Util::Storage.stubs(:load)
        Oregano::Configurer.any_instance.stubs(:save_last_run_summary) # to prevent it from trying to write files
      end

      after :each do
        Oregano::Node::Facts.indirection.reset_terminus_class
        Oregano::Node::Facts.indirection.cache_class = nil
      end

      around :each do |example|
        Oregano.override(:current_environment =>
                        Oregano::Node::Environment.create(:production, [])) do
          example.run
        end
      end

      it "should set the code to run from --code" do
        @apply.options[:code] = "code to run"
        Oregano.expects(:[]=).with(:code,"code to run")

        expect { @apply.main }.to exit_with 0
      end

      it "should set the code to run from STDIN if no arguments" do
        @apply.command_line.stubs(:args).returns([])
        STDIN.stubs(:read).returns("code to run")

        Oregano.expects(:[]=).with(:code,"code to run")

        expect { @apply.main }.to exit_with 0
      end

      it "should raise an error if a file is passed on command line and the file does not exist" do
        noexist = tmpfile('noexist.pp')
        @apply.command_line.stubs(:args).returns([noexist])
        expect { @apply.main }.to raise_error(RuntimeError, "Could not find file #{noexist}")
      end

      it "should set the manifest to the first file and warn other files will be skipped" do
        manifest = tmpfile('starwarsIV')
        FileUtils.touch(manifest)

        @apply.command_line.stubs(:args).returns([manifest, 'starwarsI', 'starwarsII'])

        expect { @apply.main }.to exit_with 0

        msg = @logs.find {|m| m.message =~ /Only one file can be applied per run/ }
        expect(msg.message).to eq('Only one file can be applied per run.  Skipping starwarsI, starwarsII')
        expect(msg.level).to eq(:warning)
      end

      it "should splay" do
        @apply.expects(:splay)

        expect { @apply.main }.to exit_with 0
      end

      it "should raise an error if we can't find the node" do
        Oregano::Node.indirection.expects(:find).returns(nil)

        expect { @apply.main }.to raise_error(RuntimeError, /Could not find node/)
      end

      it "should load custom classes if loadclasses" do
        @apply.options[:loadclasses] = true
        classfile = tmpfile('classfile')
        File.open(classfile, 'w') { |c| c.puts 'class' }
        Oregano[:classfile] = classfile

        @node.expects(:classes=).with(['class'])

        expect { @apply.main }.to exit_with 0
      end

      it "should compile the catalog" do
        Oregano::Resource::Catalog.indirection.expects(:find).returns(@catalog)

        expect { @apply.main }.to exit_with 0
      end

      it 'should make the Oregano::Pops::Loaders available when applying the compiled catalog' do
        Oregano::Resource::Catalog.indirection.expects(:find).returns(@catalog)
        @apply.expects(:apply_catalog).with(@catalog) do
          fail('Loaders not found') unless Oregano.lookup(:loaders) { nil }.is_a?(Oregano::Pops::Loaders)
          true
        end.returns(0)
        expect { @apply.main }.to exit_with 0
      end

      it "should transform the catalog to ral" do

        @catalog.expects(:to_ral).returns(@catalog)

        expect { @apply.main }.to exit_with 0
      end

      it "should finalize the catalog" do
        @catalog.expects(:finalize)

        expect { @apply.main }.to exit_with 0
      end

      it "should not save the classes or resource file by default" do
        @catalog.expects(:write_class_file).never
        @catalog.expects(:write_resource_file).never
        expect { @apply.main }.to exit_with 0
      end

      it "should save the classes and resources files when requested" do
        @apply.options[:write_catalog_summary] = true

        @catalog.expects(:write_class_file).once
        @catalog.expects(:write_resource_file).once

        expect { @apply.main }.to exit_with 0
      end

      it "should call the prerun and postrun commands on a Configurer instance" do
        Oregano::Configurer.any_instance.expects(:execute_prerun_command).returns(true)
        Oregano::Configurer.any_instance.expects(:execute_postrun_command).returns(true)

        expect { @apply.main }.to exit_with 0
      end

      it "should apply the catalog" do
        @catalog.expects(:apply).returns(stub_everything('transaction'))

        expect { @apply.main }.to exit_with 0
      end

      it "should save the last run summary" do
        Oregano[:noop] = false
        report = Oregano::Transaction::Report.new
        Oregano::Transaction::Report.stubs(:new).returns(report)

        Oregano::Configurer.any_instance.expects(:save_last_run_summary).with(report)
        expect { @apply.main }.to exit_with 0
      end

      describe "when using node_name_fact" do
        before :each do
          @facts = Oregano::Node::Facts.new(Oregano[:node_name_value], 'my_name_fact' => 'other_node_name')
          Oregano::Node::Facts.indirection.save(@facts)
          @node = Oregano::Node.new('other_node_name')
          Oregano::Node.indirection.save(@node)
          Oregano[:node_name_fact] = 'my_name_fact'
        end

        it "should set the facts name based on the node_name_fact" do
          expect { @apply.main }.to exit_with 0
          expect(@facts.name).to eq('other_node_name')
        end

        it "should set the node_name_value based on the node_name_fact" do
          expect { @apply.main }.to exit_with 0
          expect(Oregano[:node_name_value]).to eq('other_node_name')
        end

        it "should merge in our node the loaded facts" do
          @facts.values.merge!('key' => 'value')

          expect { @apply.main }.to exit_with 0

          expect(@node.parameters['key']).to eq('value')
        end

        it "should raise an error if we can't find the facts" do
          Oregano::Node::Facts.indirection.expects(:find).returns(nil)

          expect { @apply.main }.to raise_error(RuntimeError, /Could not find facts/)
        end
      end

      describe "with detailed_exitcodes" do
        before :each do
          @apply.options[:detailed_exitcodes] = true
        end

        it "should exit with report's computed exit status" do
          Oregano[:noop] = false
          Oregano::Transaction::Report.any_instance.stubs(:exit_status).returns(666)

          expect { @apply.main }.to exit_with 666
        end

        it "should exit with report's computed exit status, even if --noop is set" do
          Oregano[:noop] = true
          Oregano::Transaction::Report.any_instance.stubs(:exit_status).returns(666)

          expect { @apply.main }.to exit_with 666
        end

        it "should always exit with 0 if option is disabled" do
          Oregano[:noop] = false
          report = stub 'report', :exit_status => 666
          @transaction.stubs(:report).returns(report)

          expect { @apply.main }.to exit_with 0
        end

        it "should always exit with 0 if --noop" do
          Oregano[:noop] = true
          report = stub 'report', :exit_status => 666
          @transaction.stubs(:report).returns(report)

          expect { @apply.main }.to exit_with 0
        end
      end
    end

    describe "the 'apply' command" do
      # We want this memoized, and to be able to adjust the content, so we
      # have to do it ourselves.
      def temporary_catalog(content = '"something"')
        @tempfile = Tempfile.new('catalog.json')
        @tempfile.write(content)
        @tempfile.close
        @tempfile.path
      end

      it "should read the catalog in from disk if a file name is provided" do
        @apply.options[:catalog] = temporary_catalog
        catalog = Oregano::Resource::Catalog.new("testing", Oregano::Node::Environment::NONE)
        Oregano::Resource::Catalog.stubs(:convert_from).with(:json,'"something"').returns(catalog)
        @apply.apply
      end

      it "should read the catalog in from stdin if '-' is provided" do
        @apply.options[:catalog] = "-"
        $stdin.expects(:read).returns '"something"'
        catalog = Oregano::Resource::Catalog.new("testing", Oregano::Node::Environment::NONE)
        Oregano::Resource::Catalog.stubs(:convert_from).with(:json,'"something"').returns(catalog)
        @apply.apply
      end

      it "should deserialize the catalog from the default format" do
        @apply.options[:catalog] = temporary_catalog
        Oregano::Resource::Catalog.stubs(:default_format).returns :rot13_piglatin
        catalog = Oregano::Resource::Catalog.new("testing", Oregano::Node::Environment::NONE)
        Oregano::Resource::Catalog.stubs(:convert_from).with(:rot13_piglatin,'"something"').returns(catalog)
        @apply.apply
      end

      it "should fail helpfully if deserializing fails" do
        @apply.options[:catalog] = temporary_catalog('something syntactically invalid')
        expect { @apply.apply }.to raise_error(Oregano::Error)
      end

      it "should convert the catalog to a RAL catalog and use a Configurer instance to apply it" do
        @apply.options[:catalog] = temporary_catalog
        catalog = Oregano::Resource::Catalog.new("testing", Oregano::Node::Environment::NONE)
        Oregano::Resource::Catalog.stubs(:convert_from).with(:json,'"something"').returns catalog
        catalog.expects(:to_ral).returns "mycatalog"

        configurer = stub 'configurer'
        Oregano::Configurer.expects(:new).returns configurer
        configurer.expects(:run).
          with(:catalog => "mycatalog", :pluginsync => false)

        @apply.apply
      end

      it 'should make the Oregano::Pops::Loaders available when applying a catalog' do
        @apply.options[:catalog] = temporary_catalog
        catalog = Oregano::Resource::Catalog.new("testing", Oregano::Node::Environment::NONE)
        @apply.expects(:read_catalog).with('something') do
          fail('Loaders not found') unless Oregano.lookup(:loaders) { nil }.is_a?(Oregano::Pops::Loaders)
          true
        end.returns(catalog)
        @apply.expects(:apply_catalog).with(catalog) do
          fail('Loaders not found') unless Oregano.lookup(:loaders) { nil }.is_a?(Oregano::Pops::Loaders)
          true
        end
        expect { @apply.apply }.not_to raise_error
      end
    end
  end

  describe "apply_catalog" do
    it "should call the configurer with the catalog" do
      catalog = "I am a catalog"
      Oregano::Configurer.any_instance.expects(:run).
        with(:catalog => catalog, :pluginsync => false)
      @apply.send(:apply_catalog, catalog)
    end
  end

  it "should honor the catalog_cache_terminus setting" do
    Oregano.settings[:catalog_cache_terminus] = "json"
    Oregano::Resource::Catalog.indirection.expects(:cache_class=).with(:json)

    @apply.initialize_app_defaults
    @apply.setup
  end

  it "should set catalog cache class to nil during a noop run" do
    Oregano[:catalog_cache_terminus] = "json"
    Oregano[:noop] = true
    Oregano::Resource::Catalog.indirection.expects(:cache_class=).with(nil)

    @apply.initialize_app_defaults
    @apply.setup
  end
end
