#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/configurer'
require 'oregano/configurer/plugin_handler'

describe Oregano::Configurer::PluginHandler do
  let(:factory)       { Oregano::Configurer::DownloaderFactory.new }
  let(:pluginhandler) { Oregano::Configurer::PluginHandler.new(factory) }
  let(:environment)   { Oregano::Node::Environment.create(:myenv, []) }

  before :each do
    # PluginHandler#load_plugin has an extra-strong rescue clause
    # this mock is to make sure that we don't silently ignore errors
    Oregano.expects(:err).never
  end

  it "downloads plugins and facts" do
    plugin_downloader = stub('plugin-downloader', :evaluate => [])
    facts_downloader = stub('facts-downloader', :evaluate => [])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)

    pluginhandler.download_plugins(environment)
  end

  it "returns downloaded plugin and fact filenames" do
    plugin_downloader = stub('plugin-downloader', :evaluate => %w[/a])
    facts_downloader = stub('facts-downloader', :evaluate => %w[/b])

    factory.expects(:create_plugin_downloader).returns(plugin_downloader)
    factory.expects(:create_plugin_facts_downloader).returns(facts_downloader)

    expect(pluginhandler.download_plugins(environment)).to match_array(%w[/a /b])
  end
end
