#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/face'

describe Oregano::Face[:node, '0.0.1'] do
  after :all do
    Oregano::SSL::Host.ca_location = :none
  end

  describe '#cleanup' do
    it "should clean everything" do
      {
        "cert"         => ['hostname'],
        "cached_facts" => ['hostname'],
        "cached_node"  => ['hostname'],
        "reports"      => ['hostname'],
      }.each { |k, v| subject.expects("clean_#{k}".to_sym).with(*v) }
      subject.cleanup('hostname')
    end
  end

  describe 'when running #clean' do
    before :each do
      Oregano::Node::Facts.indirection.stubs(:terminus_class=)
      Oregano::Node::Facts.indirection.stubs(:cache_class=)
      Oregano::Node.stubs(:terminus_class=)
      Oregano::Node.stubs(:cache_class=)
    end

    it 'should invoke #cleanup' do
      subject.expects(:cleanup).with('hostname', nil)
      subject.clean('hostname')
    end
  end

  describe "clean action" do
    before :each do
      Oregano::Node::Facts.indirection.stubs(:terminus_class=)
      Oregano::Node::Facts.indirection.stubs(:cache_class=)
      Oregano::Node.stubs(:terminus_class=)
      Oregano::Node.stubs(:cache_class=)
      subject.stubs(:cleanup)
    end

    it "should have a clean action" do
      expect(subject).to be_action :clean
    end

    it "should not accept a call with no arguments" do
      expect { subject.clean() }.to raise_error(RuntimeError, /At least one node should be passed/)
    end

    it "should accept a node name" do
      expect { subject.clean('hostname') }.to_not raise_error
    end

    it "should accept more than one node name" do
      expect do
        subject.clean('hostname', 'hostname2', {})
      end.to_not raise_error

      expect do
        subject.clean('hostname', 'hostname2', 'hostname3')
      end.to_not raise_error
    end

    context "clean action" do
      subject { Oregano::Face[:node, :current] }
      before :each do
        Oregano::Util::Log.stubs(:newdestination)
        Oregano::Util::Log.stubs(:level=)
      end

      describe "during setup" do
        it "should set facts terminus and cache class to yaml" do
          Oregano::Node::Facts.indirection.expects(:terminus_class=).with(:yaml)
          Oregano::Node::Facts.indirection.expects(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should run in master mode" do
          subject.clean('hostname')
          expect(Oregano.run_mode).to be_master
        end

        it "should set node cache as yaml" do
          Oregano::Node.indirection.expects(:terminus_class=).with(:yaml)
          Oregano::Node.indirection.expects(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should manage the certs if the host is a CA" do
          Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(true)
          Oregano::SSL::Host.expects(:ca_location=).with(:local)
          subject.clean('hostname')
        end

        it "should not manage the certs if the host is not a CA" do
          Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(false)
          Oregano::SSL::Host.expects(:ca_location=).with(:none)
          subject.clean('hostname')
        end
      end

      describe "when cleaning certificate" do
        before :each do
          Oregano::SSL::Host.stubs(:destroy)
          @ca = mock()
          Oregano::SSL::CertificateAuthority.stubs(:instance).returns(@ca)
        end

        it "should send the :destroy order to the ca if we are a CA" do
          Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(true)
          @ca.expects(:revoke).with(@host)
          @ca.expects(:destroy).with(@host)
          subject.clean_cert(@host)
        end

        it "should not destroy the certs if we are not a CA" do
          Oregano::SSL::CertificateAuthority.stubs(:ca?).returns(false)
          @ca.expects(:revoke).never
          @ca.expects(:destroy).never
          subject.clean_cert(@host)
        end
      end

      describe "when cleaning cached facts" do
        it "should destroy facts" do
          @host = 'node'
          Oregano::Node::Facts.indirection.expects(:destroy).with(@host)

          subject.clean_cached_facts(@host)
        end
      end

      describe "when cleaning cached node" do
        it "should destroy the cached node" do
          Oregano::Node.indirection.expects(:destroy).with(@host)
          subject.clean_cached_node(@host)
        end
      end

      describe "when cleaning archived reports" do
        it "should tell the reports to remove themselves" do
          Oregano::Transaction::Report.indirection.stubs(:destroy).with(@host)

          subject.clean_reports(@host)
        end
      end
    end
  end
end
