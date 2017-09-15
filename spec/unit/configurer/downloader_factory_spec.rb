#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/configurer'

describe Oregano::Configurer::DownloaderFactory do
  let(:factory)     { Oregano::Configurer::DownloaderFactory.new }
  let(:environment) { Oregano::Node::Environment.create(:myenv, []) }

  let(:plugin_downloader) do
    factory.create_plugin_downloader(environment)
  end

  let(:facts_downloader) do
    factory.create_plugin_facts_downloader(environment)
  end

  def ignores_source_permissions(downloader)
    expect(downloader.file[:source_permissions]).to eq(:ignore)
  end

  def uses_source_permissions(downloader)
    expect(downloader.file[:source_permissions]).to eq(:use)
  end

  context "when creating a plugin downloader for modules" do
    it 'is named "plugin"' do
      expect(plugin_downloader.name).to eq('plugin')
    end

    it 'downloads files into Oregano[:plugindest]' do
      plugindest = File.expand_path("/tmp/pdest")
      Oregano[:plugindest] = plugindest

      expect(plugin_downloader.file[:path]).to eq(plugindest)
    end

    it 'downloads files from Oregano[:pluginsource]' do
      Oregano[:pluginsource] = 'oregano:///myotherplugins'

      expect(plugin_downloader.file[:source]).to eq([Oregano[:pluginsource]])
    end

    it 'ignores files from Oregano[:pluginsignore]' do
      Oregano[:pluginsignore] = 'pignore'

      expect(plugin_downloader.file[:ignore]).to eq(['pignore'])
    end

    it 'splits Oregano[:pluginsignore] on whitespace' do
      Oregano[:pluginsignore] = ".svn CVS .git"

      expect(plugin_downloader.file[:ignore]).to eq(%w[.svn CVS .git])
    end

    it "ignores source permissions" do
      ignores_source_permissions(plugin_downloader)
    end
  end

  context "when creating a plugin downloader for external facts" do
    it 'is named "pluginfacts"' do
      expect(facts_downloader.name).to eq('pluginfacts')
    end

    it 'downloads files into Oregano[:pluginfactdest]' do
      plugindest = File.expand_path("/tmp/pdest")
      Oregano[:pluginfactdest] = plugindest

      expect(facts_downloader.file[:path]).to eq(plugindest)
    end

    it 'downloads files from Oregano[:pluginfactsource]' do
      Oregano[:pluginfactsource] = 'oregano:///myotherfacts'

      expect(facts_downloader.file[:source]).to eq([Oregano[:pluginfactsource]])
    end

    it 'ignores files from Oregano[:pluginsignore]' do
      Oregano[:pluginsignore] = 'pignore'

      expect(facts_downloader.file[:ignore]).to eq(['pignore'])
    end

    context "on POSIX", :if => Oregano.features.posix? do
      it "uses source permissions" do
        uses_source_permissions(facts_downloader)
      end
    end

    context "on Windows", :if => Oregano.features.microsoft_windows? do
      it "ignores source permissions during external fact pluginsync" do
        ignores_source_permissions(facts_downloader)
      end
    end
  end
end
