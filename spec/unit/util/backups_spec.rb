#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/util/backups'

describe Oregano::Util::Backups do
  include OreganoSpec::Files

  let(:bucket) { stub('bucket', :name => "foo") }
  let!(:file) do
    f = Oregano::Type.type(:file).new(:name => path, :backup => 'foo')
    f.stubs(:bucket).returns(bucket)
    f
  end

  describe "when backing up a file" do
    let(:path) { make_absolute('/no/such/file') }

    it "should noop if the file does not exist" do
      file = Oregano::Type.type(:file).new(:name => path)

      file.expects(:bucket).never
      Oregano::FileSystem.expects(:exist?).with(path).returns false

      file.perform_backup
    end

    it "should succeed silently if self[:backup] is false" do
      file = Oregano::Type.type(:file).new(:name => path, :backup => false)

      file.expects(:bucket).never
      Oregano::FileSystem.expects(:exist?).never

      file.perform_backup
    end

    it "a bucket should be used when provided" do
      lstat_path_as(path, 'file')
      bucket.expects(:backup).with(path).returns("mysum")
      Oregano::FileSystem.expects(:exist?).with(path).returns(true)

      file.perform_backup
    end

    it "should propagate any exceptions encountered when backing up to a filebucket" do
      lstat_path_as(path, 'file')
      bucket.expects(:backup).raises ArgumentError
      Oregano::FileSystem.expects(:exist?).with(path).returns(true)

      expect { file.perform_backup }.to raise_error(ArgumentError)
    end

    describe "and local backup is configured" do
      let(:ext) { 'foobkp' }
      let(:backup) { path + '.' + ext }
      let(:file) { Oregano::Type.type(:file).new(:name => path, :backup => '.'+ext) }

      it "should remove any local backup if one exists" do
        lstat_path_as(backup, 'file')
        Oregano::FileSystem.expects(:unlink).with(backup)
        FileUtils.stubs(:cp_r)
        Oregano::FileSystem.expects(:exist?).with(path).returns(true)

        file.perform_backup
      end

      it "should fail when the old backup can't be removed" do
        lstat_path_as(backup, 'file')
        Oregano::FileSystem.expects(:unlink).with(backup).raises ArgumentError
        FileUtils.expects(:cp_r).never
        Oregano::FileSystem.expects(:exist?).with(path).returns(true)

        expect { file.perform_backup }.to raise_error(Oregano::Error)
      end

      it "should not try to remove backups that don't exist" do
        Oregano::FileSystem.expects(:lstat).with(backup).raises(Errno::ENOENT)
        Oregano::FileSystem.expects(:unlink).with(backup).never
        FileUtils.stubs(:cp_r)
        Oregano::FileSystem.expects(:exist?).with(path).returns(true)

        file.perform_backup
      end

      it "a copy should be created in the local directory" do
        FileUtils.expects(:cp_r).with(path, backup, :preserve => true)
        Oregano::FileSystem.stubs(:exist?).with(path).returns(true)

        expect(file.perform_backup).to be_truthy
      end

      it "should propagate exceptions if no backup can be created" do
        FileUtils.expects(:cp_r).raises ArgumentError

        Oregano::FileSystem.stubs(:exist?).with(path).returns(true)
        expect { file.perform_backup }.to raise_error(Oregano::Error)
      end
    end
  end

  describe "when backing up a directory" do
    let(:path) { make_absolute('/my/dir') }
    let(:filename) { File.join(path, 'file') }

    it "a bucket should work when provided" do
      File.stubs(:file?).with(filename).returns true
      Find.expects(:find).with(path).yields(filename)

      bucket.expects(:backup).with(filename).returns true

      lstat_path_as(path, 'directory')

      Oregano::FileSystem.stubs(:exist?).with(path).returns(true)
      Oregano::FileSystem.stubs(:exist?).with(filename).returns(true)

      file.perform_backup
    end

    it "should do nothing when recursing" do
      file = Oregano::Type.type(:file).new(:name => path, :backup => 'foo', :recurse => true)

      bucket.expects(:backup).never
      stub_file = stub('file', :stat => stub('stat', :ftype => 'directory'))
      Oregano::FileSystem.stubs(:new).with(path).returns stub_file
      Find.expects(:find).never

      file.perform_backup
    end
  end

  def lstat_path_as(path, ftype)
    Oregano::FileSystem.expects(:lstat).with(path).returns(stub('File::Stat', :ftype => ftype))
  end
end
