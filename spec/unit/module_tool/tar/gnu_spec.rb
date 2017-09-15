require 'spec_helper'
require 'oregano/module_tool'

describe Oregano::ModuleTool::Tar::Gnu do
  let(:sourcefile) { '/space path/the/module.tar.gz' }
  let(:destdir)    { '/space path/the/dest/dir' }
  let(:sourcedir)  { '/space path/the/src/dir' }
  let(:destfile)   { '/space path/the/dest/file.tar.gz' }

  it "unpacks a tar file" do
    Dir.expects(:chdir).with(File.expand_path(destdir)).yields(mock)
    Oregano::Util::Execution.expects(:execute).with("gzip -dc #{Shellwords.shellescape(File.expand_path(sourcefile))} | tar xof -")
    Oregano::Util::Execution.expects(:execute).with("find . -type d -exec chmod 755 {} +")
    Oregano::Util::Execution.expects(:execute).with("find . -type f -exec chmod u+rw,g+r,a-st {} +")
    Oregano::Util::Execution.expects(:execute).with("chown -R <owner:group> .")
    subject.unpack(sourcefile, destdir, '<owner:group>')
  end

  it "packs a tar file" do
    Oregano::Util::Execution.expects(:execute).with("tar cf - #{sourcedir} | gzip -c > #{File.basename(destfile)}")
    subject.pack(sourcedir, destfile)
  end
end
