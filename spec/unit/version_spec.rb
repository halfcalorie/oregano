require "spec_helper"
require "oregano/version"
require 'pathname'

describe "Oregano.version Public API" do
  before :each do
    @current_ver = Oregano.version
    Oregano.instance_eval do
      if @oregano_version
        @oregano_version = nil
      end
    end
  end

  after :each do
    Oregano.version = @current_ver
  end

  context "without a VERSION file" do
    before :each do
      Oregano.stubs(:read_version_file).returns(nil)
    end

    it "is Oregano::PUPPETVERSION" do
      expect(Oregano.version).to eq(Oregano::PUPPETVERSION)
    end
    it "respects the version= setter" do
      Oregano.version = '1.2.3'
      expect(Oregano.version).to eq('1.2.3')
      expect(Oregano.minor_version).to eq('1.2')
    end
  end

  context "with a VERSION file" do
    it "is the content of the file" do
      Oregano.expects(:read_version_file).with() do |path|
        pathname = Pathname.new(path)
        pathname.basename.to_s == "VERSION"
      end.returns('3.0.1-260-g9ca4e54')

      expect(Oregano.version).to eq('3.0.1-260-g9ca4e54')
      expect(Oregano.minor_version).to eq('3.0')
    end
    it "respects the version= setter" do
      Oregano.version = '1.2.3'
      expect(Oregano.version).to eq('1.2.3')
      expect(Oregano.minor_version).to eq('1.2')
    end
  end

  context "Using version setter" do
    it "does not read VERSION file if using set version" do
      Oregano.expects(:read_version_file).never
      Oregano.version = '1.2.3'
      expect(Oregano.version).to eq('1.2.3')
      expect(Oregano.minor_version).to eq('1.2')
    end
  end
end


