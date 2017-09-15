#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

module OreganoFaceSpecs 
describe Oregano::Face[:config, '0.0.1'] do

  FS = Oregano::FileSystem

  it "prints a single setting without the name" do
    Oregano[:trace] = true

    expect { subject.print("trace") }.to have_printed('true')
  end

  it "prints multiple settings with the names" do
    Oregano[:trace] = true
    Oregano[:syslogfacility] = "file"

    expect { subject.print("trace", "syslogfacility") }.to have_printed(<<-OUTPUT)
trace = true
syslogfacility = file
    OUTPUT
  end

  it "prints the setting from the selected section" do
    Oregano.settings.parse_config(<<-CONF)
    [user]
    syslogfacility = file
    CONF

    expect { subject.print("syslogfacility", :section => "user") }.to have_printed('file')
  end

  it "defaults to all when no arguments are given" do
    subject.expects(:puts).times(Oregano.settings.to_a.length)

    subject.print
  end

  it "prints out all of the settings when asked for 'all'" do
    subject.expects(:puts).times(Oregano.settings.to_a.length)

    subject.print('all')
  end

  context "when setting config values" do
    let(:config_file) { '/foo/oregano.conf' }
    let(:path) { Pathname.new(config_file).expand_path }
    before(:each) do
      Oregano[:config] = config_file
      Oregano::FileSystem.stubs(:pathname).with(path.to_s).returns(path)
      Oregano::FileSystem.stubs(:touch)
    end

    it "writes to the correct oregano config file" do
      Oregano::FileSystem.expects(:open).with(path, anything, anything)
      subject.set('foo', 'bar')
    end

    it "creates a config file if one does not exist" do
      Oregano::FileSystem.stubs(:open).with(path, anything, anything).yields(StringIO.new)
      Oregano::FileSystem.expects(:touch).with(path)
      subject.set('foo', 'bar')
    end

    it "sets the supplied config/value in the default section (main)" do
      Oregano::FileSystem.stubs(:open).with(path, anything, anything).yields(StringIO.new)
      config = Oregano::Settings::IniFile.new([Oregano::Settings::IniFile::DefaultSection.new])
      manipulator = Oregano::Settings::IniFile::Manipulator.new(config)
      Oregano::Settings::IniFile::Manipulator.stubs(:new).returns(manipulator)

      manipulator.expects(:set).with("main", "foo", "bar")
      subject.set('foo', 'bar')
    end

    it "sets the value in the supplied section" do
      Oregano::FileSystem.stubs(:open).with(path, anything, anything).yields(StringIO.new)
      config = Oregano::Settings::IniFile.new([Oregano::Settings::IniFile::DefaultSection.new])
      manipulator = Oregano::Settings::IniFile::Manipulator.new(config)
      Oregano::Settings::IniFile::Manipulator.stubs(:new).returns(manipulator)

      manipulator.expects(:set).with("baz", "foo", "bar")
      subject.set('foo', 'bar', {:section => "baz"})

    end

    it "opens the file with UTF-8 encoding" do
      Oregano::FileSystem.expects(:open).with(path, nil, 'r+:UTF-8')
      subject.set('foo', 'bar')
    end
  end

  shared_examples_for :config_printing_a_section do |section|

    def add_section_option(args, section)
      args << { :section => section } if section
      args
    end

    it "prints directory env settings for an env that exists" do
      FS.overlay(
        FS::MemoryFile.a_directory(File.expand_path("/dev/null/environments"), [
          FS::MemoryFile.a_directory("production", [
            FS::MemoryFile.a_missing_file("environment.conf"),
          ]),
        ])
      ) do
        args = "environmentpath","manifest","modulepath","environment","basemodulepath"
        expect { subject.print(*add_section_option(args, section)) }.to have_printed(<<-OUTPUT)
environmentpath = #{File.expand_path("/dev/null/environments")}
manifest = #{File.expand_path("/dev/null/environments/production/manifests")}
modulepath = #{File.expand_path("/dev/null/environments/production/modules")}#{File::PATH_SEPARATOR}#{File.expand_path("/some/base")}
environment = production
basemodulepath = #{File.expand_path("/some/base")}
        OUTPUT
      end
    end

    it "interpolates settings in environment.conf" do
      FS.overlay(
        FS::MemoryFile.a_directory(File.expand_path("/dev/null/environments"), [
          FS::MemoryFile.a_directory("production", [
            FS::MemoryFile.a_regular_file_containing("environment.conf", <<-CONTENT),
            modulepath=/custom/modules#{File::PATH_SEPARATOR}$basemodulepath
            CONTENT
          ]),
        ])
      ) do
        args = "environmentpath","manifest","modulepath","environment","basemodulepath"
        expect { subject.print(*add_section_option(args, section)) }.to have_printed(<<-OUTPUT)
environmentpath = #{File.expand_path("/dev/null/environments")}
manifest = #{File.expand_path("/dev/null/environments/production/manifests")}
modulepath = #{File.expand_path("/custom/modules")}#{File::PATH_SEPARATOR}#{File.expand_path("/some/base")}
environment = production
basemodulepath = #{File.expand_path("/some/base")}
        OUTPUT
      end
    end

    it "prints the default configured env settings for an env that does not exist" do
      pending "This case no longer exists because Application will through an error before we even get here because of the non-existent environment"
      Oregano[:environment] = 'doesnotexist'

      FS.overlay(
        FS::MemoryFile.a_directory(File.expand_path("/dev/null/environments"), [
          FS::MemoryFile.a_missing_file("doesnotexist")
        ])
      ) do
        args = "environmentpath","manifest","modulepath","environment","basemodulepath"
        expect { subject.print(*add_section_option(args, section)) }.to have_printed(<<-OUTPUT)
environmentpath = #{File.expand_path("/dev/null/environments")}
manifest = no_manifest
modulepath = 
environment = doesnotexist
basemodulepath = #{File.expand_path("/some/base")}
        OUTPUT
      end
    end
  end

  context "when printing environment settings" do
    context "from main section" do
      before(:each) do
        Oregano.settings.parse_config(<<-CONF)
        [main]
        environmentpath=$confdir/environments
        basemodulepath=/some/base
        CONF
      end

      it_behaves_like :config_printing_a_section, nil
    end

    context "from master section" do

      before(:each) do
        Oregano.settings.parse_config(<<-CONF)
        [master]
        environmentpath=$confdir/environments
        basemodulepath=/some/base
        CONF
      end

      it_behaves_like :config_printing_a_section, :master
    end
  end
end
end
