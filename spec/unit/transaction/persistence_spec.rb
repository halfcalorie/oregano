#! /usr/bin/env ruby
require 'spec_helper'

require 'yaml'
require 'fileutils'
require 'oregano/transaction/persistence'

describe Oregano::Transaction::Persistence do
  include OreganoSpec::Files

  before(:each) do
    @basepath = File.expand_path("/somepath")
  end

  describe "when loading from file" do
    before do
      Oregano.settings.stubs(:use).returns(true)
    end

    describe "when the file/directory does not exist" do
      before(:each) do
        @path = tmpfile('storage_test')
      end

      it "should not fail to load" do
        expect(Oregano::FileSystem.exist?(@path)).to be_falsey
        Oregano[:statedir] = @path
        persistence = Oregano::Transaction::Persistence.new
        persistence.load
        Oregano[:transactionstorefile] = @path
        persistence = Oregano::Transaction::Persistence.new
        persistence.load
      end
    end

    describe "when the file/directory exists" do
      before(:each) do
        @tmpfile = tmpfile('storage_test')
        Oregano[:transactionstorefile] = @tmpfile
      end

      def write_state_file(contents)
        File.open(@tmpfile, 'w') { |f| f.write(contents) }
      end

      it "should overwrite its internal state if load() is called" do
        resource = "Foo[bar]"
        property = "my"
        value = "something"

        Oregano.expects(:err).never

        persistence = Oregano::Transaction::Persistence.new
        persistence.set_system_value(resource, property, value)

        persistence.load

        expect(persistence.get_system_value(resource, property)).to eq(nil)
      end

      it "should restore its internal state if the file contains valid YAML" do
        test_yaml = {"resources"=>{"a"=>"b"}}
        write_state_file(test_yaml.to_yaml)

        Oregano.expects(:err).never

        persistence = Oregano::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq(test_yaml)
      end

      it "should initialize with a clear internal state if the file does not contain valid YAML" do
        write_state_file('{ invalid')

        Oregano.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))

        persistence = Oregano::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should initialize with a clear internal state if the file does not contain a hash of data" do
        write_state_file("not_a_hash")

        Oregano.expects(:err).with(regexp_matches(/Transaction store file .* is valid YAML but not returning a hash/))

        persistence = Oregano::Transaction::Persistence.new
        persistence.load

        expect(persistence.data).to eq({})
      end

      it "should raise an error if the file does not contain valid YAML and cannot be renamed" do
        write_state_file('{ invalid')

        File.expects(:rename).raises(SystemCallError)

        Oregano.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))
        Oregano.expects(:err).with(regexp_matches(/Unable to rename/))

        persistence = Oregano::Transaction::Persistence.new
        expect { persistence.load }.to raise_error(Oregano::Error, /Could not rename/)
      end

      it "should attempt to rename the file if the file is corrupted" do
        write_state_file('{ invalid')

        File.expects(:rename).at_least_once

        Oregano.expects(:err).with(regexp_matches(/Transaction store file .* is corrupt/))

        persistence = Oregano::Transaction::Persistence.new
        persistence.load
      end

      it "should fail gracefully on load() if the file is not a regular file" do
        FileUtils.rm_f(@tmpfile)
        Dir.mkdir(@tmpfile)

        Oregano.expects(:warning).with(regexp_matches(/Transaction store file .* is not a file/))

        persistence = Oregano::Transaction::Persistence.new
        persistence.load
      end
    end
  end

  describe "when storing to the file" do
    before(:each) do
      @tmpfile = tmpfile('persistence_test')
      @saved = Oregano[:transactionstorefile]
      Oregano[:transactionstorefile] = @tmpfile
    end

    it "should create the file if it does not exist" do
      expect(Oregano::FileSystem.exist?(Oregano[:transactionstorefile])).to be_falsey

      persistence = Oregano::Transaction::Persistence.new
      persistence.save

      expect(Oregano::FileSystem.exist?(Oregano[:transactionstorefile])).to be_truthy
    end

    it "should raise an exception if the file is not a regular file" do
      Dir.mkdir(Oregano[:transactionstorefile])
      persistence = Oregano::Transaction::Persistence.new

      if Oregano.features.microsoft_windows?
        expect do
          persistence.save
        end.to raise_error do |error|
          expect(error).to be_a(Oregano::Util::Windows::Error)
          expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
        end
      else
        expect { persistence.save }.to raise_error(Errno::EISDIR, /Is a directory/)
      end

      Dir.rmdir(Oregano[:transactionstorefile])
    end

    it "should load the same information that it saves" do
      resource = "File[/tmp/foo]"
      property = "content"
      value = "foo"

      persistence = Oregano::Transaction::Persistence.new
      persistence.set_system_value(resource, property, value)

      persistence.save
      persistence.load

      expect(persistence.get_system_value(resource, property)).to eq(value)
    end
  end
end
