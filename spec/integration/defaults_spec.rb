#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/defaults'

describe "Oregano defaults" do

  describe "when default_manifest is set" do
    it "returns ./manifests by default" do
      expect(Oregano[:default_manifest]).to eq('./manifests')
    end
  end

  describe "when disable_per_environment_manifest is set" do
    it "returns false by default" do
      expect(Oregano[:disable_per_environment_manifest]).to eq(false)
    end

    it "errors when set to true and default_manifest is not an absolute path" do
      expect {
        Oregano[:default_manifest] = './some/relative/manifest.pp'
        Oregano[:disable_per_environment_manifest] = true
      }.to raise_error Oregano::Settings::ValidationError, /'default_manifest' setting must be.*absolute/
    end
  end

  describe "when setting the :factpath" do
    it "should add the :factpath to Facter's search paths" do
      Facter.expects(:search).with("/my/fact/path")

      Oregano.settings[:factpath] = "/my/fact/path"
    end
  end

  describe "when setting the :certname" do
    it "should fail if the certname is not downcased" do
      expect { Oregano.settings[:certname] = "Host.Domain.Com" }.to raise_error(ArgumentError)
    end
  end

  describe "when setting :node_name_value" do
    it "should default to the value of :certname" do
      Oregano.settings[:certname] = 'blargle'
      expect(Oregano.settings[:node_name_value]).to eq('blargle')
    end
  end

  describe "when setting the :node_name_fact" do
    it "should fail when also setting :node_name_value" do
      expect do
        Oregano.settings[:node_name_value] = "some value"
        Oregano.settings[:node_name_fact] = "some_fact"
      end.to raise_error("Cannot specify both the node_name_value and node_name_fact settings")
    end

    it "should not fail when using the default for :node_name_value" do
      expect do
        Oregano.settings[:node_name_fact] = "some_fact"
      end.not_to raise_error
    end
  end

  it "should have a clientyamldir setting" do
    expect(Oregano.settings[:clientyamldir]).not_to be_nil
  end

  it "should have different values for the yamldir and clientyamldir" do
    expect(Oregano.settings[:yamldir]).not_to eq(Oregano.settings[:clientyamldir])
  end

  it "should have a client_datadir setting" do
    expect(Oregano.settings[:client_datadir]).not_to be_nil
  end

  it "should have different values for the server_datadir and client_datadir" do
    expect(Oregano.settings[:server_datadir]).not_to eq(Oregano.settings[:client_datadir])
  end

  # See #1232
  it "should not specify a user or group for the clientyamldir" do
    expect(Oregano.settings.setting(:clientyamldir).owner).to be_nil
    expect(Oregano.settings.setting(:clientyamldir).group).to be_nil
  end

  it "should use the service user and group for the yamldir" do
    Oregano.settings.stubs(:service_user_available?).returns true
    Oregano.settings.stubs(:service_group_available?).returns true
    expect(Oregano.settings.setting(:yamldir).owner).to eq(Oregano.settings[:user])
    expect(Oregano.settings.setting(:yamldir).group).to eq(Oregano.settings[:group])
  end

  it "should specify that the host private key should be owned by the service user" do
    Oregano.settings.stubs(:service_user_available?).returns true
    expect(Oregano.settings.setting(:hostprivkey).owner).to eq(Oregano.settings[:user])
  end

  it "should specify that the host certificate should be owned by the service user" do
    Oregano.settings.stubs(:service_user_available?).returns true
    expect(Oregano.settings.setting(:hostcert).owner).to eq(Oregano.settings[:user])
  end

  [:modulepath, :factpath].each do |setting|
    it "should configure '#{setting}' not to be a file setting, so multi-directory settings are acceptable" do
      expect(Oregano.settings.setting(setting)).to be_instance_of(Oregano::Settings::PathSetting)
    end
  end

  describe "on a Unix-like platform it", :if => Oregano.features.posix? do
    it "should add /usr/sbin and /sbin to the path if they're not there" do
      Oregano::Util.withenv("PATH" => "/usr/bin#{File::PATH_SEPARATOR}/usr/local/bin") do
        Oregano.settings[:path] = "none" # this causes it to ignore the setting
        expect(ENV["PATH"].split(File::PATH_SEPARATOR)).to be_include("/usr/sbin")
        expect(ENV["PATH"].split(File::PATH_SEPARATOR)).to be_include("/sbin")
      end
    end
  end

  describe "on a Windows-like platform it", :if => Oregano.features.microsoft_windows? do
    let (:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }

    it "path should not add anything" do
      path = "c:\\windows\\system32#{File::PATH_SEPARATOR}c:\\windows"
      Oregano::Util.withenv( {"PATH" => path }, :windows ) do
        Oregano.settings[:path] = "none" # this causes it to ignore the setting
        expect(ENV["PATH"]).to eq(path)
      end
    end

    it "path should support UTF8 characters" do
      path = "c:\\windows\\system32#{File::PATH_SEPARATOR}c:\\windows#{File::PATH_SEPARATOR}C:\\" + rune_utf8
      Oregano::Util.withenv( {"PATH" => path }, :windows) do
        Oregano.settings[:path] = "none" # this causes it to ignore the setting

        envhash = Oregano::Util::Windows::Process.get_environment_strings
        expect(envhash['Path']).to eq(path)
      end
    end
  end

  it "should default to json for the preferred serialization format" do
    expect(Oregano.settings.value(:preferred_serialization_format)).to eq("json")
  end

  it "should have a setting for determining the configuration version and should default to an empty string" do
    expect(Oregano.settings[:config_version]).to eq("")
  end

  describe "when enabling reports" do
    it "should use the default server value when report server is unspecified" do
      Oregano.settings[:server] = "server"
      expect(Oregano.settings[:report_server]).to eq("server")
    end

    it "should use the default masterport value when report port is unspecified" do
      Oregano.settings[:masterport] = "1234"
      expect(Oregano.settings[:report_port]).to eq("1234")
    end

    it "should use report_port when set" do
      Oregano.settings[:masterport] = "1234"
      Oregano.settings[:report_port] = "5678"
      expect(Oregano.settings[:report_port]).to eq("5678")
    end
  end

  it "should have a :caname setting that defaults to the cert name" do
    Oregano.settings[:certname] = "foo"
    expect(Oregano.settings[:ca_name]).to eq("Oregano CA: foo")
  end

  it "should have a 'prerun_command' that defaults to the empty string" do
    expect(Oregano.settings[:prerun_command]).to eq("")
  end

  it "should have a 'postrun_command' that defaults to the empty string" do
    expect(Oregano.settings[:postrun_command]).to eq("")
  end

  it "should have a 'certificate_revocation' setting that defaults to true" do
    expect(Oregano.settings[:certificate_revocation]).to be_truthy
  end

  describe "reportdir" do
    subject { Oregano.settings[:reportdir] }
    it { is_expected.to eq("#{Oregano[:vardir]}/reports") }
  end

  describe "reporturl" do
    subject { Oregano.settings[:reporturl] }
    it { is_expected.to eq("http://localhost:3000/reports/upload") }
  end

  describe "when configuring color" do
    subject { Oregano.settings[:color] }
    it { is_expected.to eq("ansi") }
  end

  describe "daemonize" do
    it "should default to true", :unless => Oregano.features.microsoft_windows? do
      expect(Oregano.settings[:daemonize]).to eq(true)
    end

    describe "on Windows", :if => Oregano.features.microsoft_windows? do
      it "should default to false" do
        expect(Oregano.settings[:daemonize]).to eq(false)
      end

      it "should raise an error if set to true" do
        expect { Oregano.settings[:daemonize] = true }.to raise_error(/Cannot daemonize on Windows/)
      end
    end
  end

  describe "diff" do
    it "should default to 'diff' on POSIX", :unless => Oregano.features.microsoft_windows? do
      expect(Oregano.settings[:diff]).to eq('diff')
    end

    it "should default to '' on Windows", :if => Oregano.features.microsoft_windows? do
      expect(Oregano.settings[:diff]).to eq('')
    end
  end

  describe "when configuring hiera" do
    it "should have a hiera_config setting" do
      expect(Oregano.settings[:hiera_config]).not_to be_nil
    end
  end

  describe "when configuring the data_binding terminus" do
    it "should have a data_binding_terminus setting" do
      expect(Oregano.settings[:data_binding_terminus]).not_to be_nil
    end

    it "should be set to hiera by default" do
      expect(Oregano.settings[:data_binding_terminus]).to eq(:hiera)
    end

    it "to be neither 'hiera' nor 'none', a deprecation warning is logged" do
      expect(@logs).to eql([])
      Oregano[:data_binding_terminus] = 'magic'
      expect(@logs[0].to_s).to match(/Setting 'data_binding_terminus' is deprecated/)
    end

    it "to not log a warning if set to 'none' or 'hiera'" do
      expect(@logs).to eql([])
      Oregano[:data_binding_terminus] = 'none'
      Oregano[:data_binding_terminus] = 'hiera'
      expect(@logs).to eql([])
    end
  end

  describe "agent_catalog_run_lockfile" do
    it "(#2888) is not a file setting so it is absent from the Settings catalog" do
      expect(Oregano.settings.setting(:agent_catalog_run_lockfile)).not_to be_a_kind_of Oregano::Settings::FileSetting
      expect(Oregano.settings.setting(:agent_catalog_run_lockfile)).to be_a Oregano::Settings::StringSetting
    end
  end
end
