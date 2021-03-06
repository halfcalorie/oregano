require 'spec_helper'
require 'oregano/module_tool'

describe Oregano::ModuleTool::Tar::Mini, :if => (Oregano.features.minitar? and Oregano.features.zlib?) do
  let(:sourcefile) { '/the/module.tar.gz' }
  let(:destdir)    { File.expand_path '/the/dest/dir' }
  let(:sourcedir)  { '/the/src/dir' }
  let(:destfile)   { '/the/dest/file.tar.gz' }
  let(:minitar)    { described_class.new }

  it "unpacks a tar file" do
    unpacks_the_entry(:file_start, 'thefile')

    minitar.unpack(sourcefile, destdir, 'uid')
  end

  it "does not allow an absolute path" do
    unpacks_the_entry(:file_start, '/thefile')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Oregano::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"/thefile\" under \"#{destdir}\"")
  end

  it "does not allow a file to be written outside the destination directory" do
    unpacks_the_entry(:file_start, '../../thefile')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Oregano::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"#{File.expand_path('/the/thefile')}\" under \"#{destdir}\"")
  end

  it "does not allow a directory to be written outside the destination directory" do
    unpacks_the_entry(:dir, '../../thedir')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Oregano::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"#{File.expand_path('/the/thedir')}\" under \"#{destdir}\"")
  end

  it "packs a tar file" do
    writer = stub('GzipWriter')

    Zlib::GzipWriter.expects(:open).with(destfile).yields(writer)
    Archive::Tar::Minitar.expects(:pack).with(sourcedir, writer)

    minitar.pack(sourcedir, destfile)
  end

  def unpacks_the_entry(type, name)
    reader = stub('GzipReader')

    Zlib::GzipReader.expects(:open).with(sourcefile).yields(reader)
    minitar.expects(:find_valid_files).with(reader).returns([name])
    Archive::Tar::Minitar.expects(:unpack).with(reader, destdir, [name]).yields(type, name, nil)
  end
end
