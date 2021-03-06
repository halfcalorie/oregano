#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/reports'

processor = Oregano::Reports.report(:http)

describe processor do
  subject { Oregano::Transaction::Report.new.extend(processor) }

  describe "when setting up the connection" do
    let(:http) { stub_everything "http" }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }

    before :each do
      http.expects(:post).returns(httpok)
    end

    it "configures the connection for ssl when using https" do
      Oregano[:reporturl] = 'https://testing:8080/the/path'

      Oregano::Network::HttpPool.expects(:http_instance).with(
        'testing', 8080, true
      ).returns http

      subject.process
    end

    it "does not configure the connectino for ssl when using http" do
      Oregano[:reporturl] = "http://testing:8080/the/path"

      Oregano::Network::HttpPool.expects(:http_instance).with(
        'testing', 8080, false
      ).returns http

      subject.process
    end
  end

  describe "when making a request" do
    let(:connection) { stub_everything "connection" }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }
    let(:options) { {:metric_id => [:oregano, :report, :http]} }

    before :each do
      Oregano::Network::HttpPool.expects(:http_instance).returns(connection)
    end

    it "should use the path specified by the 'reporturl' setting" do
      report_path = URI.parse(Oregano[:reporturl]).path
      connection.expects(:post).with(report_path, anything, anything, options).returns(httpok)

      subject.process
    end

    it "should use the username and password specified by the 'reporturl' setting" do
      Oregano[:reporturl] = "https://user:pass@myhost.mydomain:1234/report/upload"

      connection.expects(:post).with(anything, anything, anything,
                                     {:metric_id => [:oregano, :report, :http],
                                      :basic_auth => {
                                        :user => 'user',
                                        :password => 'pass'
                                      }}).returns(httpok)

      subject.process
    end

    it "should give the body as the report as YAML" do
      connection.expects(:post).with(anything, subject.to_yaml, anything, options).returns(httpok)

      subject.process
    end

    it "should set content-type to 'application/x-yaml'" do
      connection.expects(:post).with(anything, anything, has_entry("Content-Type" => "application/x-yaml"), options).returns(httpok)

      subject.process
    end

    Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
      if code.to_i >= 200 and code.to_i < 300
        it "should succeed on http code #{code}" do
          response = klass.new('1.1', code, '')
          connection.expects(:post).returns(response)

          Oregano.expects(:err).never
          subject.process
        end
      end

      if code.to_i >= 300 && ![301, 302, 307].include?(code.to_i)
        it "should log error on http code #{code}" do
          response = klass.new('1.1', code, '')
          connection.expects(:post).returns(response)

          Oregano.expects(:err)
          subject.process
        end
      end
    end

  end
end
