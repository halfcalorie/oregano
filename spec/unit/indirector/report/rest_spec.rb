#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/report/rest'

describe Oregano::Transaction::Report::Rest do
  it "should be a subclass of Oregano::Indirector::REST" do
    expect(Oregano::Transaction::Report::Rest.superclass).to equal(Oregano::Indirector::REST)
  end

  it "should use the :report_server setting in preference to :server" do
    Oregano.settings[:server] = "server"
    Oregano.settings[:report_server] = "report_server"
    expect(Oregano::Transaction::Report::Rest.server).to eq("report_server")
  end

  it "should have a value for report_server and report_port" do
    expect(Oregano::Transaction::Report::Rest.server).not_to be_nil
    expect(Oregano::Transaction::Report::Rest.port).not_to be_nil
  end

  it "should use the :report SRV service" do
    expect(Oregano::Transaction::Report::Rest.srv_service).to eq(:report)
  end

  let(:model) { Oregano::Transaction::Report }
  let(:terminus_class) { Oregano::Transaction::Report::Rest }
  let(:terminus) { model.indirection.terminus(:rest) }
  let(:indirection) { model.indirection }

  before(:each) do
    Oregano::Transaction::Report.indirection.terminus_class = :rest
  end

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = stub('http 200 ok', :code => code.to_s, :body => body)
    obj.stubs(:[]).with('content-type').returns(content_type)
    obj.stubs(:[]).with('content-encoding').returns(encoding)
    obj.stubs(:[]).with(Oregano::Network::HTTP::HEADER_PUPPET_VERSION).returns(Oregano.version)
    obj
  end

  def save_request(key, instance, options={})
    Oregano::Indirector::Request.new(:report, :find, key, instance, options)
  end

  describe "#save" do
    let(:response) { mock_response(200, 'body') }
    let(:connection) { stub('mock http connection', :put => response, :verify_callback= => nil) }
    let(:instance) { model.new('the thing', 'some contents') }
    let(:request) { save_request(instance.name, instance) }
    let(:body) { ["store", "http"].to_pson }

    before :each do
      terminus.stubs(:network).returns(connection)
    end

    it "deserializes the response as an array of report processor names" do
      response = mock_response('200', body, 'text/pson')
      connection.expects(:put).returns response

      expect(terminus.save(request)).to eq(["store", "http"])
    end

    describe "when handling the response" do
      describe "when the server major version is less than 5" do
        it "raises if the save fails and we're not using pson" do
          Oregano[:preferred_serialization_format] = "json"

          response = mock_response('500', '{}', 'text/pson')
          response.stubs(:[]).with(Oregano::Network::HTTP::HEADER_PUPPET_VERSION).returns("4.10.1")
          connection.expects(:put).returns response

          expect {
            terminus.save(request)
          }.to raise_error(Oregano::Error, /Server version 4.10.1 does not accept reports in 'json'/)
        end

        it "raises with HTTP 500 if the save fails and we're already using pson" do
          Oregano[:preferred_serialization_format] = "pson"

          response = mock_response('500', '{}', 'text/pson')
          response.stubs(:[]).with(Oregano::Network::HTTP::HEADER_PUPPET_VERSION).returns("4.10.1")
          connection.expects(:put).returns response

          expect {
            terminus.save(request)
          }.to raise_error(Net::HTTPError, /Error 500 on SERVER/)
        end
      end
    end
  end
end
