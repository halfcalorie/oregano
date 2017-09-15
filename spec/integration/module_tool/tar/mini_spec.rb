require 'spec_helper'
require 'oregano/module_tool'
require 'oregano_spec/files'

describe Oregano::ModuleTool::Tar::Mini, :if => (Oregano.features.minitar? && Oregano.features.zlib?) do
  let(:minitar)    { described_class.new }

  describe "Extracts tars with long and short pathnames" do
    let (:sourcetar) { File.expand_path('../../../../fixtures/module.tar.gz', __FILE__) }

    let (:longfilepath)  { "oreganolabs-dsc-1.0.0/lib/oregano_x/dsc_resources/xWebAdministration/DSCResources/MSFT_xWebAppPoolDefaults/MSFT_xWebAppPoolDefaults.schema.mof" }
    let (:shortfilepath) { "oreganolabs-dsc-1.0.0/README.md" }

    it "unpacks a tar with a short path length" do
      extractdir = OreganoSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{shortfilepath}"))
    end

    it "unpacks a tar with a long path length" do
      extractdir = OreganoSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{longfilepath}"))
    end
  end
end