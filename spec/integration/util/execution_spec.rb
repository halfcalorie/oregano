require 'spec_helper'

describe Oregano::Util::Execution do
  include OreganoSpec::Files

  describe "#execpipe" do
    it "should set LANG to C avoid localized output", :if => !Oregano.features.microsoft_windows? do
      out = ""
      Oregano::Util::Execution.execpipe('echo $LANG'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end

    it "should set LC_ALL to C avoid localized output", :if => !Oregano.features.microsoft_windows? do
      out = ""
      Oregano::Util::Execution.execpipe('echo $LC_ALL'){ |line| out << line.read.chomp }
      expect(out).to eq("C")
    end

    it "should raise an ExecutionFailure with a missing command and :failonfail set to true" do
      expect {
        failonfail = true
        # NOTE: critical to return l in the block for `output` in method to be #<IO:(closed)>
        Oregano::Util::Execution.execpipe('conan_the_librarion', failonfail) { |l| l }
      }.to raise_error(Oregano::ExecutionFailure)
    end
  end

  describe "#execute (non-Windows)", :if => !Oregano.features.microsoft_windows? do
    it "should execute basic shell command" do
      result = Oregano::Util::Execution.execute("ls /tmp", :failonfail => true)
      expect(result.exitstatus).to eq(0)
      expect(result.to_s).to_not be_nil
    end
  end

  describe "#execute (Windows)", :if => Oregano.features.microsoft_windows? do
    let(:utf8text) do
      # Japanese Lorem Ipsum snippet
      "utf8testfile" + [227, 131, 171, 227, 131, 147, 227, 131, 179, 227, 131, 132, 227,
                        130, 162, 227, 130, 166, 227, 130, 167, 227, 131, 150, 227, 130,
                        162, 227, 129, 181, 227, 129, 185, 227, 129, 139, 227, 130, 137,
                        227, 129, 154, 227, 130, 187, 227, 130, 183, 227, 131, 147, 227,
                        131, 170, 227, 131, 134].pack('c*').force_encoding(Encoding::UTF_8)
    end
    let(:temputf8filename) do
      script_containing(utf8text, :windows => "@ECHO OFF\r\nECHO #{utf8text}\r\nEXIT 100")
    end

    it "should execute with non-english characters in command line" do
      result = Oregano::Util::Execution.execute("cmd /c \"#{temputf8filename}\"", :failonfail => false)
      expect(temputf8filename.encoding.name).to eq('UTF-8')
      expect(result.exitstatus).to eq(100)
    end
  end
end
