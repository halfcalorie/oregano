#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:plugin, :current] do

  let(:pluginface) { described_class }
  let(:action) { pluginface.get_action(:download) }

  def render(result)
    action.when_rendering(:console).call(result)
  end

  context "download" do
    it "downloads plugins and external facts" do
      Oregano::Configurer::Downloader.any_instance.expects(:evaluate).twice.returns([])

      pluginface.download
    end

    it "renders 'No plugins downloaded' if nothing was downloaded" do
      Oregano::Configurer::Downloader.any_instance.expects(:evaluate).twice.returns([])

      result = pluginface.download
      expect(render(result)).to eq('No plugins downloaded.')
    end

    it "renders comma separate list of downloaded file names" do
      Oregano::Configurer::Downloader.any_instance.expects(:evaluate).twice.returns(%w[/a]).then.returns(%w[/b])

      result = pluginface.download
      expect(render(result)).to eq('Downloaded these plugins: /a, /b')
    end
  end
end
