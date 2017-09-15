#! /usr/bin/env ruby

require 'spec_helper'

describe "Oregano::Util::Windows::User", :if => Oregano.features.microsoft_windows? do
  describe "2003 without UAC" do
    before :each do
      Oregano::Util::Windows::Process.stubs(:windows_major_version).returns(5)
    end

    it "should be an admin if user's token contains the Administrators SID" do
      Oregano::Util::Windows::User.expects(:check_token_membership).returns(true)
      Oregano::Util::Windows::Process.expects(:elevated_security?).never

      expect(Oregano::Util::Windows::User).to be_admin
    end

    it "should not be an admin if user's token doesn't contain the Administrators SID" do
      Oregano::Util::Windows::User.expects(:check_token_membership).returns(false)
      Oregano::Util::Windows::Process.expects(:elevated_security?).never

      expect(Oregano::Util::Windows::User).not_to be_admin
    end

    it "should raise an exception if we can't check token membership" do
      Oregano::Util::Windows::User.expects(:check_token_membership).raises(Oregano::Util::Windows::Error, "Access denied.")
      Oregano::Util::Windows::Process.expects(:elevated_security?).never

      expect { Oregano::Util::Windows::User.admin? }.to raise_error(Oregano::Util::Windows::Error, /Access denied./)
    end
  end

  describe "2008 with UAC" do
    before :each do
      Oregano::Util::Windows::Process.stubs(:windows_major_version).returns(6)
    end

    it "should be an admin if user is running with elevated privileges" do
      Oregano::Util::Windows::Process.stubs(:elevated_security?).returns(true)
      Oregano::Util::Windows::User.expects(:check_token_membership).never

      expect(Oregano::Util::Windows::User).to be_admin
    end

    it "should not be an admin if user is not running with elevated privileges" do
      Oregano::Util::Windows::Process.stubs(:elevated_security?).returns(false)
      Oregano::Util::Windows::User.expects(:check_token_membership).never

      expect(Oregano::Util::Windows::User).not_to be_admin
    end

    it "should raise an exception if the process fails to open the process token" do
      Oregano::Util::Windows::Process.stubs(:elevated_security?).raises(Oregano::Util::Windows::Error, "Access denied.")
      Oregano::Util::Windows::User.expects(:check_token_membership).never

      expect { Oregano::Util::Windows::User.admin? }.to raise_error(Oregano::Util::Windows::Error, /Access denied./)
    end
  end

  describe "module function" do
    let(:username) { 'fabio' }
    let(:bad_password) { 'goldilocks' }
    let(:logon_fail_msg) { /Failed to logon user "fabio":  Logon failure: unknown user name or bad password./ }

    def expect_logon_failure_error(&block)
      expect {
        yield
      }.to raise_error { |error|
        expect(error).to be_a(Oregano::Util::Windows::Error)
        # https://msdn.microsoft.com/en-us/library/windows/desktop/ms681385(v=vs.85).aspx
        # ERROR_LOGON_FAILURE 1326
        expect(error.code).to eq(1326)
      }
    end

    describe "load_profile" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Oregano::Util::Windows::User.load_profile(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Oregano::Util::Windows::User.load_profile(username, nil)
        }
      end
    end

    describe "logon_user" do
      it "should raise an error when provided with an incorrect username and password" do
        expect_logon_failure_error {
          Oregano::Util::Windows::User.logon_user(username, bad_password)
        }
      end

      it "should raise an error when provided with an incorrect username and nil password" do
        expect_logon_failure_error {
          Oregano::Util::Windows::User.logon_user(username, nil)
        }
      end
    end

    describe "password_is?" do
      it "should return false given an incorrect username and password" do
        expect(Oregano::Util::Windows::User.password_is?(username, bad_password)).to be_falsey
      end

      it "should return false given a nil username and an incorrect password" do
        expect(Oregano::Util::Windows::User.password_is?(nil, bad_password)).to be_falsey
      end

      context "with a correct password" do
        it "should return true even if account restrictions are in place " do
          error = Oregano::Util::Windows::Error.new('', Oregano::Util::Windows::User::ERROR_ACCOUNT_RESTRICTION)
          Oregano::Util::Windows::User.stubs(:logon_user).raises(error)
          expect(Oregano::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for an account outside of logon hours" do
          error = Oregano::Util::Windows::Error.new('', Oregano::Util::Windows::User::ERROR_INVALID_LOGON_HOURS)
          Oregano::Util::Windows::User.stubs(:logon_user).raises(error)
          expect(Oregano::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for an account not allowed to log into this workstation" do
          error = Oregano::Util::Windows::Error.new('', Oregano::Util::Windows::User::ERROR_INVALID_WORKSTATION)
          Oregano::Util::Windows::User.stubs(:logon_user).raises(error)
          expect(Oregano::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end

        it "should return true even for a disabled account" do
          error = Oregano::Util::Windows::Error.new('', Oregano::Util::Windows::User::ERROR_ACCOUNT_DISABLED)
          Oregano::Util::Windows::User.stubs(:logon_user).raises(error)
          expect(Oregano::Util::Windows::User.password_is?(username, 'p@ssword')).to be(true)
        end
      end
    end

    describe "check_token_membership" do
      it "should not raise an error" do
        # added just to call an FFI code path on all platforms
        expect { Oregano::Util::Windows::User.check_token_membership }.not_to raise_error
      end
    end
  end
end
