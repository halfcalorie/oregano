#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/network/http'
require 'oregano/network/http/api/indirected_routes'
require 'oregano/network/authorization'

describe Oregano::Network::Authorization do
  class AuthTest
    include Oregano::Network::Authorization
  end

  subject { AuthTest.new }

  context "when creating an authconfig object" do
    before :each do
      # Other tests may have created an authconfig, so we have to undo that.
      @orig_auth_config = Oregano::Network::AuthConfigLoader.instance_variable_get(:@auth_config)
      @orig_auth_config_file = Oregano::Network::AuthConfigLoader.instance_variable_get(:@auth_config_file)

      Oregano::Network::AuthConfigLoader.instance_variable_set(:@auth_config, nil)
      Oregano::Network::AuthConfigLoader.instance_variable_set(:@auth_config_file, nil)
    end

    after :each do
      Oregano::Network::AuthConfigLoader.instance_variable_set(:@auth_config, @orig_auth_config)
      Oregano::Network::AuthConfigLoader.instance_variable_set(:@auth_config_file, @orig_auth_config_file)
    end

    it "creates default ACL entries if no file has been read" do
      Oregano::Network::AuthConfigParser.expects(:new_from_file).raises Errno::ENOENT
      Oregano::Network::DefaultAuthProvider.any_instance.expects(:insert_default_acl)

      subject.authconfig
    end
  end

  class TestAuthConfig
    def check_authorization(method, path, params); end
  end

  class TestAuthConfigLoader
    def self.authconfig
      TestAuthConfig.new
    end
  end

  context "when checking authorization" do
    after :each do
      Oregano::Network::Authorization.authconfigloader_class = nil
    end

    it "delegates to the authconfig object" do
      Oregano::Network::Authorization.authconfigloader_class =
          TestAuthConfigLoader
      TestAuthConfig.any_instance.expects(:check_authorization).with(
          :save, '/mypath', {:param1 => "value1"}).returns("yay, it worked!")
      expect(subject.check_authorization(
                 :save, '/mypath',
                 {:param1 => "value1"})).to eq("yay, it worked!")
    end
  end
end
