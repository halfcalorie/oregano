#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Util::RunMode do

  # Discriminator for tests that attempts to unset HOME since that, for reasons currently unknown,
  # doesn't work in Ruby >= 2.4.0
  def self.gte_ruby_2_4
    @gte_ruby_2_4 ||= SemanticOregano::Version.parse(RUBY_VERSION) >= SemanticOregano::Version.parse('2.4.0')
  end

  before do
    @run_mode = Oregano::Util::RunMode.new('fake')
  end

  describe Oregano::Util::UnixRunMode, :unless => Oregano.features.microsoft_windows? do
    before do
      @run_mode = Oregano::Util::UnixRunMode.new('fake')
    end

    describe "#conf_dir" do
      it "has confdir /etc/oreganolabs/oregano when run as root" do
        as_root { expect(@run_mode.conf_dir).to eq(File.expand_path('/etc/oreganolabs/oregano')) }
      end

      it "has confdir ~/.oreganolabs/etc/oregano when run as non-root" do
        as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path('~/.oreganolabs/etc/oregano')) }
      end

      context "master run mode" do
        before do
          @run_mode = Oregano::Util::UnixRunMode.new('master')
        end
        it "has confdir ~/.oreganolabs/etc/oregano when run as non-root and master run mode" do
          as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path('~/.oreganolabs/etc/oregano')) }
        end
      end

      it "fails when asking for the conf_dir as non-root and there is no $HOME", :unless => gte_ruby_2_4 || Oregano.features.microsoft_windows? do
        as_non_root do
          without_home do
            expect { @run_mode.conf_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#code_dir" do
      it "has codedir /etc/oreganolabs/code when run as root" do
        as_root { expect(@run_mode.code_dir).to eq(File.expand_path('/etc/oreganolabs/code')) }
      end

      it "has codedir ~/.oreganolabs/etc/code when run as non-root" do
        as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path('~/.oreganolabs/etc/code')) }
      end

      context "master run mode" do
        before do
          @run_mode = Oregano::Util::UnixRunMode.new('master')
        end

        it "has codedir ~/.oreganolabs/etc/code when run as non-root and master run mode" do
          as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path('~/.oreganolabs/etc/code')) }
        end
      end

      it "fails when asking for the code_dir as non-root and there is no $HOME", :unless => gte_ruby_2_4 || Oregano.features.microsoft_windows? do
        as_non_root do
          without_home do
            expect { @run_mode.code_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#var_dir" do
      it "has vardir /opt/oreganolabs/oregano/cache when run as root" do
        as_root { expect(@run_mode.var_dir).to eq(File.expand_path('/opt/oreganolabs/oregano/cache')) }
      end

      it "has vardir ~/.oreganolabs/opt/oregano/cache when run as non-root" do
        as_non_root { expect(@run_mode.var_dir).to eq(File.expand_path('~/.oreganolabs/opt/oregano/cache')) }
      end

      it "fails when asking for the var_dir as non-root and there is no $HOME", :unless => gte_ruby_2_4 || Oregano.features.microsoft_windows? do
        as_non_root do
          without_home do
            expect { @run_mode.var_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#log_dir" do
      describe "when run as root" do
        it "has logdir /var/log/oreganolabs/oregano" do
          as_root { expect(@run_mode.log_dir).to eq(File.expand_path('/var/log/oreganolabs/oregano')) }
        end
      end

      describe "when run as non-root" do
        it "has default logdir ~/.oreganolabs/var/log" do
          as_non_root { expect(@run_mode.log_dir).to eq(File.expand_path('~/.oreganolabs/var/log')) }
        end

        it "fails when asking for the log_dir and there is no $HOME", :unless => gte_ruby_2_4 || Oregano.features.microsoft_windows? do
          as_non_root do
            without_home do
              expect { @run_mode.log_dir }.to raise_error ArgumentError, /couldn't find HOME/
            end
          end
        end
      end
    end

    describe "#run_dir" do
      describe "when run as root" do
        it "has rundir /var/run/oreganolabs" do
          as_root { expect(@run_mode.run_dir).to eq(File.expand_path('/var/run/oreganolabs')) }
        end
      end

      describe "when run as non-root" do
        it "has default rundir ~/.oreganolabs/var/run" do
          as_non_root { expect(@run_mode.run_dir).to eq(File.expand_path('~/.oreganolabs/var/run')) }
        end

        it "fails when asking for the run_dir and there is no $HOME", :unless => gte_ruby_2_4 || Oregano.features.microsoft_windows? do
          as_non_root do
            without_home do
              expect { @run_mode.run_dir }.to raise_error ArgumentError, /couldn't find HOME/
            end
          end
        end
      end
    end
  end

  describe Oregano::Util::WindowsRunMode, :if => Oregano.features.microsoft_windows? do
    before do
      if not Dir.const_defined? :COMMON_APPDATA
        Dir.const_set :COMMON_APPDATA, "/CommonFakeBase"
        @remove_const = true
      end
      @run_mode = Oregano::Util::WindowsRunMode.new('fake')
    end

    after do
      if @remove_const
        Dir.send :remove_const, :COMMON_APPDATA
      end
    end

    describe "#conf_dir" do
      it "has confdir ending in Oreganolabs/oregano/etc when run as root" do
        as_root { expect(@run_mode.conf_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "OreganoLabs", "oregano", "etc"))) }
      end

      it "has confdir in ~/.oreganolabs/etc/oregano when run as non-root" do
        as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path("~/.oreganolabs/etc/oregano")) }
      end

      it "fails when asking for the conf_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%", :unless => gte_ruby_2_4 do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.conf_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#code_dir" do
      it "has codedir ending in OreganoLabs/code when run as root" do
        as_root { expect(@run_mode.code_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "OreganoLabs", "code"))) }
      end

      it "has codedir in ~/.oreganolabs/etc/code when run as non-root" do
        as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path("~/.oreganolabs/etc/code")) }
      end

      it "fails when asking for the code_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%", :unless => gte_ruby_2_4 do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.code_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#var_dir" do
      it "has vardir ending in OreganoLabs/oregano/cache when run as root" do
        as_root { expect(@run_mode.var_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "OreganoLabs", "oregano", "cache"))) }
      end

      it "has vardir in ~/.oreganolabs/opt/oregano/cache when run as non-root" do
        as_non_root { expect(@run_mode.var_dir).to eq(File.expand_path("~/.oreganolabs/opt/oregano/cache")) }
      end

      it "fails when asking for the conf_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%", :unless => gte_ruby_2_4 do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.var_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#log_dir" do
      describe "when run as root" do
        it "has logdir ending in OreganoLabs/oregano/var/log" do
          as_root { expect(@run_mode.log_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "OreganoLabs", "oregano", "var", "log"))) }
        end
      end

      describe "when run as non-root" do
        it "has default logdir ~/.oreganolabs/var/log" do
          as_non_root { expect(@run_mode.log_dir).to eq(File.expand_path('~/.oreganolabs/var/log')) }
        end

        it "fails when asking for the log_dir and there is no $HOME", :unless => gte_ruby_2_4 do
          as_non_root do
            without_env('HOME') do
              without_env('HOMEDRIVE') do
                without_env('USERPROFILE') do
                  expect { @run_mode.log_dir }.to raise_error ArgumentError, /couldn't find HOME/
                end
              end
            end
          end
        end
      end
    end

    describe "#run_dir" do
      describe "when run as root" do
        it "has rundir ending in OreganoLabs/oregano/var/run" do
          as_root { expect(@run_mode.run_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "OreganoLabs", "oregano", "var", "run"))) }
        end
      end

      describe "when run as non-root" do
        it "has default rundir ~/.oreganolabs/var/run" do
          as_non_root { expect(@run_mode.run_dir).to eq(File.expand_path('~/.oreganolabs/var/run')) }
        end

        it "fails when asking for the run_dir and there is no $HOME", :unless => gte_ruby_2_4 do
          as_non_root do
            without_env('HOME') do
              without_env('HOMEDRIVE') do
                without_env('USERPROFILE') do
                  expect { @run_mode.run_dir }.to raise_error ArgumentError, /couldn't find HOME/
                end
              end
            end
          end
        end
      end
    end

    describe "#without_env internal helper with UTF8 characters" do
      let(:varname) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }
      let(:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }

      before do
        Oregano::Util::Windows::Process.set_environment_variable(varname, rune_utf8)
      end

      it "removes environment variables within the block with UTF8 name" do
        without_env(varname) do
          expect(ENV[varname]).to be(nil)
        end
      end

      it "restores UTF8 characters in environment variable values" do
        without_env(varname) do
          Oregano::Util::Windows::Process.set_environment_variable(varname, 'bad value')
        end

        envhash = Oregano::Util::Windows::Process.get_environment_strings
        expect(envhash[varname]).to eq(rune_utf8)
      end
    end
  end

  def as_root
    Oregano.features.stubs(:root?).returns(true)
    yield
  end

  def as_non_root
    Oregano.features.stubs(:root?).returns(false)
    yield
  end

  def without_env(name, &block)
    saved = Oregano::Util.get_env(name)
    Oregano::Util.set_env(name, nil)
    yield
  ensure
    Oregano::Util.set_env(name, saved)
  end

  def without_home(&block)
    without_env('HOME', &block)
  end
end
