#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/file_bucket/file'


describe Oregano::FileBucket::File, :uses_checksums => true do
  include OreganoSpec::Files

  # this is the default from spec_helper, but it keeps getting reset at odd times
  let(:bucketdir) { Oregano[:bucketdir] = tmpdir('bucket') }

  it "defaults to serializing to `:binary`" do
    expect(Oregano::FileBucket::File.default_format).to eq(:binary)
  end

  it "only accepts binary" do
    expect(Oregano::FileBucket::File.supported_formats).to eq([:binary])
  end

  describe "making round trips through network formats" do
    with_digest_algorithms do
      it "can make a round trip through `binary`" do
        file = Oregano::FileBucket::File.new(plaintext)
        tripped = Oregano::FileBucket::File.convert_from(:binary, file.render)
        expect(tripped.contents).to eq(plaintext)
      end
    end
  end

  it "should require contents to be a string" do
    expect { Oregano::FileBucket::File.new(5) }.to raise_error(ArgumentError, /contents must be a String or Pathname, got a (?:Fixnum|Integer)$/)
  end

  it "should complain about options other than :bucket_path" do
    expect {
      Oregano::FileBucket::File.new('5', :crazy_option => 'should not be passed')
    }.to raise_error(ArgumentError, /Unknown option\(s\): crazy_option/)
  end

  with_digest_algorithms do
    it "it uses #{metadata[:digest_algorithm]} as the configured digest algorithm" do
      file = Oregano::FileBucket::File.new(plaintext)

      expect(file.contents).to eq(plaintext)
      expect(file.checksum_type).to eq(digest_algorithm)
      expect(file.checksum).to eq("{#{digest_algorithm}}#{checksum}")
      expect(file.name).to eq("#{digest_algorithm}/#{checksum}")
    end
  end

  describe "when using back-ends" do
    it "should redirect using Oregano::Indirector" do
      expect(Oregano::Indirector::Indirection.instance(:file_bucket_file).model).to equal(Oregano::FileBucket::File)
    end

    it "should have a :save instance method" do
      expect(Oregano::FileBucket::File.indirection).to respond_to(:save)
    end
  end
end
