require 'spec_helper'
require 'oregano/face'
require 'oregano/file_serving/metadata'
require 'oregano/file_serving/content'
require 'oregano/indirector/memory'

module OreganoFaceIntegrationSpecs
describe "Oregano plugin face" do
  INDIRECTORS = [
    Oregano::Indirector::FileMetadata,
    Oregano::Indirector::FileContent,
  ]

  INDIRECTED_CLASSES = [
    Oregano::FileServing::Metadata,
    Oregano::FileServing::Content,
    Oregano::Node::Facts,
  ]

  INDIRECTORS.each do |indirector|
    class indirector::Memory < Oregano::Indirector::Memory
      def find(request)
        model.new('/dev/null', { 'type' => 'directory' })
      end
    end
  end

  before do
    FileUtils.mkdir(File.join(Oregano[:vardir], 'lib'))
    FileUtils.mkdir(File.join(Oregano[:vardir], 'facts.d'))
    @termini_classes = {}
    INDIRECTED_CLASSES.each do |indirected|
      @termini_classes[indirected] = indirected.indirection.terminus_class
      indirected.indirection.terminus_class = :memory
    end
  end

  after do
    INDIRECTED_CLASSES.each do |indirected|
      indirected.indirection.terminus_class = @termini_classes[indirected]
      indirected.indirection.termini.clear
    end
  end

  def init_cli_args_and_apply_app(args = ["download"])
    Oregano::Application.find(:plugin).new(stub('command_line', :subcommand_name => :plugin, :args => args))
  end

  it "processes a download request" do
    app = init_cli_args_and_apply_app
    expect do
      expect {
        app.run
      }.to exit_with(0)
    end.to have_printed(/No plugins downloaded/)
  end
end
end
