#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/util/ldap/connection'

# So our mocks and such all work, even when ldap isn't available.
unless Oregano.features.ldap?
  class LDAP
    class Conn
      def initialize(*args)
      end
    end
    class SSLConn < Conn; end

    LDAP_OPT_PROTOCOL_VERSION = 1
    LDAP_OPT_REFERRALS = 2
    LDAP_OPT_ON = 3
  end
end

describe Oregano::Util::Ldap::Connection do
  before do
    Oregano.features.stubs(:ldap?).returns true

    @ldapconn = mock 'ldap'
    LDAP::Conn.stubs(:new).returns(@ldapconn)
    LDAP::SSLConn.stubs(:new).returns(@ldapconn)

    @ldapconn.stub_everything

    @connection = Oregano::Util::Ldap::Connection.new("host", "port")
  end


  describe "when creating connections" do
    it "should require the host and port" do
      expect { Oregano::Util::Ldap::Connection.new("myhost") }.to raise_error(ArgumentError)
    end

    it "should allow specification of a user and password" do
      expect { Oregano::Util::Ldap::Connection.new("myhost", "myport", :user => "blah", :password => "boo") }.not_to raise_error
    end

    it "should allow specification of ssl" do
      expect { Oregano::Util::Ldap::Connection.new("myhost", "myport", :ssl => :tsl) }.not_to raise_error
    end

    it "should support requiring a new connection" do
      expect { Oregano::Util::Ldap::Connection.new("myhost", "myport", :reset => true) }.not_to raise_error
    end

    it "should fail if ldap is unavailable" do
      Oregano.features.expects(:ldap?).returns(false)

      expect { Oregano::Util::Ldap::Connection.new("host", "port") }.to raise_error(Oregano::Error)
    end

    it "should use neither ssl nor tls by default" do
      LDAP::Conn.expects(:new).with("host", "port").returns(@ldapconn)

      @connection.start
    end

    it "should use LDAP::SSLConn if ssl is requested" do
      LDAP::SSLConn.expects(:new).with("host", "port").returns(@ldapconn)

      @connection.ssl = true

      @connection.start
    end

    it "should use LDAP::SSLConn and tls if tls is requested" do
      LDAP::SSLConn.expects(:new).with("host", "port", true).returns(@ldapconn)

      @connection.ssl = :tls

      @connection.start
    end

    it "should set the protocol version to 3 and enable referrals" do
      @ldapconn.expects(:set_option).with(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      @ldapconn.expects(:set_option).with(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_ON)
      @connection.start
    end

    it "should bind with the provided user and password" do
      @connection.user = "myuser"
      @connection.password = "mypassword"
      @ldapconn.expects(:simple_bind).with("myuser", "mypassword")

      @connection.start
    end

    it "should bind with no user and password if none has been provided" do
      @ldapconn.expects(:simple_bind).with(nil, nil)
      @connection.start
    end
  end

  describe "when closing connections" do
    it "should not close connections that are not open" do
      @connection.stubs(:connection).returns(@ldapconn)

      @ldapconn.expects(:bound?).returns false
      @ldapconn.expects(:unbind).never

      @connection.close
    end
  end

  it "should have a class-level method for creating a default connection" do
    expect(Oregano::Util::Ldap::Connection).to respond_to(:instance)
  end

  describe "when creating a default connection" do
    it "should use the :ldapserver setting to determine the host" do
      Oregano[:ldapserver] = "myserv"
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| host == "myserv" }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should use the :ldapport setting to determine the port" do
      Oregano[:ldapport] = "456"
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| port == "456" }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should set ssl to :tls if tls is enabled" do
      Oregano[:ldaptls] = true
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| options[:ssl] == :tls }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should set ssl to 'true' if ssl is enabled and tls is not" do
      Oregano[:ldaptls] = false
      Oregano[:ldapssl] = true
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| options[:ssl] == true }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should set ssl to false if neither ssl nor tls are enabled" do
      Oregano[:ldaptls] = false
      Oregano[:ldapssl] = false
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| options[:ssl] == false }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should set the ldapuser if one is set" do
      Oregano[:ldapuser] = "foo"
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| options[:user] == "foo" }
      Oregano::Util::Ldap::Connection.instance
    end

    it "should set the ldapuser and ldappassword if both is set" do
      Oregano[:ldapuser] = "foo"
      Oregano[:ldappassword] = "bar"
      Oregano::Util::Ldap::Connection.expects(:new).with { |host, port, options| options[:user] == "foo" and options[:password] == "bar" }
      Oregano::Util::Ldap::Connection.instance
    end
  end
end
