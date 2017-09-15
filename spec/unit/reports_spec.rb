#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/reports'

describe Oregano::Reports do
  it "should instance-load report types" do
    expect(Oregano::Reports.instance_loader(:report)).to be_instance_of(Oregano::Util::Autoload)
  end

  it "should have a method for registering report types" do
    expect(Oregano::Reports).to respond_to(:register_report)
  end

  it "should have a method for retrieving report types by name" do
    expect(Oregano::Reports).to respond_to(:report)
  end

  it "should provide a method for returning documentation for all reports" do
    Oregano::Reports.expects(:loaded_instances).with(:report).returns([:one, :two])
    one = mock 'one', :doc => "onedoc"
    two = mock 'two', :doc => "twodoc"
    Oregano::Reports.expects(:report).with(:one).returns(one)
    Oregano::Reports.expects(:report).with(:two).returns(two)

    doc = Oregano::Reports.reportdocs
    expect(doc.include?("onedoc")).to be_truthy
    expect(doc.include?("twodoc")).to be_truthy
  end
end


describe Oregano::Reports, " when loading report types" do
  it "should use the instance loader to retrieve report types" do
    Oregano::Reports.expects(:loaded_instance).with(:report, :myreporttype)
    Oregano::Reports.report(:myreporttype)
  end
end

describe Oregano::Reports, " when registering report types" do
  it "should evaluate the supplied block as code for a module" do
    Oregano::Reports.expects(:genmodule).returns(Module.new)
    Oregano::Reports.register_report(:testing) { }
  end

  it "should allow a successful report to be reloaded" do
    Oregano::Reports.register_report(:testing) { }
    Oregano::Reports.register_report(:testing) { }
  end

  it "should allow a failed report to be reloaded and show the correct exception both times" do
    expect { Oregano::Reports.register_report(:testing) { raise TypeError, 'failed report' } }.to raise_error(TypeError)
    expect { Oregano::Reports.register_report(:testing) { raise TypeError, 'failed report' } }.to raise_error(TypeError)
  end

  it "should extend the report type with the Oregano::Util::Docs module" do
    mod = stub 'module', :define_method => true

    Oregano::Reports.expects(:genmodule).with { |name, options, block| options[:extend] == Oregano::Util::Docs }.returns(mod)
    Oregano::Reports.register_report(:testing) { }
  end

  it "should define a :report_name method in the module that returns the name of the report" do
    mod = mock 'module'
    mod.expects(:define_method).with(:report_name)

    Oregano::Reports.expects(:genmodule).returns(mod)
    Oregano::Reports.register_report(:testing) { }
  end
end
