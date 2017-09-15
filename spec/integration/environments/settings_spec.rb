require 'spec_helper'
require 'oregano_spec/settings'

describe "environment settings" do
  include OreganoSpec::Settings

  let(:confdir) { Oregano[:confdir] }
  let(:cmdline_args) { ['--confdir', confdir, '--vardir', Oregano[:vardir], '--hiera_config', Oregano[:hiera_config]] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }
  let(:testingdir) { File.join(environmentpath, "testing") }

  before(:each) do
    FileUtils.mkdir_p(testingdir)
  end

  def init_oregano_conf(settings = {})
    set_oregano_conf(confdir, <<-EOF)
      environmentpath=#{environmentpath}
      #{settings.map { |k,v| "#{k}=#{v}" }.join("\n")}
    EOF
    Oregano.initialize_settings
  end

  it "raises an error if you set manifest in oregano.conf" do
    expect { init_oregano_conf("manifest" => "/something") }.to raise_error(Oregano::Settings::SettingsError, /Cannot set manifest.*in oregano.conf/)
  end

  it "raises an error if you set modulepath in oregano.conf" do
    expect { init_oregano_conf("modulepath" => "/something") }.to raise_error(Oregano::Settings::SettingsError, /Cannot set modulepath.*in oregano.conf/)
  end

  it "raises an error if you set config_version in oregano.conf" do
    expect { init_oregano_conf("config_version" => "/something") }.to raise_error(Oregano::Settings::SettingsError, /Cannot set config_version.*in oregano.conf/)
  end

  context "when given an environment" do
    before(:each) do
      init_oregano_conf
    end

    context "without an environment.conf" do
      it "reads manifest from environment.conf defaults" do
        expect(Oregano.settings.value(:manifest, :testing)).to eq(File.join(testingdir, "manifests"))
      end

      it "reads modulepath from environment.conf defaults" do
        expect(Oregano.settings.value(:modulepath, :testing)).to match(/#{File.join(testingdir, "modules")}/)
      end

      it "reads config_version from environment.conf defaults" do
        expect(Oregano.settings.value(:config_version, :testing)).to eq('')
      end
    end

    context "with an environment.conf" do
      before(:each) do
        set_environment_conf(environmentpath, 'testing', <<-EOF)
          manifest=/special/manifest
          modulepath=/special/modulepath
          config_version=/special/config_version
        EOF
      end

      it "reads the configured manifest" do
        expect(Oregano.settings.value(:manifest, :testing)).to eq(Oregano::FileSystem.expand_path('/special/manifest'))
      end

      it "reads the configured modulepath" do
        expect(Oregano.settings.value(:modulepath, :testing)).to eq(Oregano::FileSystem.expand_path('/special/modulepath'))
      end

      it "reads the configured config_version" do
        expect(Oregano.settings.value(:config_version, :testing)).to eq(Oregano::FileSystem.expand_path('/special/config_version'))
      end
    end

    context "with an environment.conf containing 8.3 style Windows paths",
      :if => Oregano::Util::Platform.windows? do

      before(:each) do
        # set 8.3 style Windows paths
        @modulepath = Oregano::Util::Windows::File.get_short_pathname(OreganoSpec::Files.tmpdir('fakemodulepath'))

        # for expansion to work, the file must actually exist
        @manifest = OreganoSpec::Files.tmpfile('foo.pp', @modulepath)
        # but tmpfile won't create an empty file
        Oregano::FileSystem.touch(@manifest)
        @manifest = Oregano::Util::Windows::File.get_short_pathname(@manifest)

        set_environment_conf(environmentpath, 'testing', <<-EOF)
          manifest=#{@manifest}
          modulepath=#{@modulepath}
        EOF
      end

      it "reads the configured manifest as a fully expanded path" do
        expect(Oregano.settings.value(:manifest, :testing)).to eq(Oregano::FileSystem.expand_path(@manifest))
      end

      it "reads the configured modulepath as a fully expanded path" do
        expect(Oregano.settings.value(:modulepath, :testing)).to eq(Oregano::FileSystem.expand_path(@modulepath))
      end
    end

    context "when environment name collides with a oregano.conf section" do
      let(:testingdir) { File.join(environmentpath, "main") }

      it "reads manifest from environment.conf defaults" do
        expect(Oregano.settings.value(:environmentpath)).to eq(environmentpath)
        expect(Oregano.settings.value(:manifest, :main)).to eq(File.join(testingdir, "manifests"))
      end

      context "and an environment.conf" do
        before(:each) do
          set_environment_conf(environmentpath, 'main', <<-EOF)
            manifest=/special/manifest
          EOF
        end

        it "reads manifest from environment.conf settings" do
          expect(Oregano.settings.value(:environmentpath)).to eq(environmentpath)
          expect(Oregano.settings.value(:manifest, :main)).to eq(Oregano::FileSystem.expand_path("/special/manifest"))
        end
      end
    end
  end

end
