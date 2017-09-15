require 'spec_helper'
require 'json'

require 'oregano/module_tool/applications'
require 'oregano/file_system'
require 'oregano_spec/modules'

describe Oregano::ModuleTool::Applications::Unpacker do
  include OreganoSpec::Files

  let(:target)      { tmpdir("unpacker") }
  let(:module_name) { 'myusername-mytarball' }
  let(:filename)    { tmpdir("module") + "/module.tar.gz" }
  let(:working_dir) { tmpdir("working_dir") }

  before :each do
    Oregano.settings.stubs(:[])
    Oregano.settings.stubs(:[]).with(:module_working_dir).returns(working_dir)
  end

  it "should attempt to untar file to temporary location" do
    untar = mock('Tar')
    untar.expects(:unpack).with(filename, anything()) do |src, dest, _|
      FileUtils.mkdir(File.join(dest, 'extractedmodule'))
      File.open(File.join(dest, 'extractedmodule', 'metadata.json'), 'w+') do |file|
        file.puts JSON.generate('name' => module_name, 'version' => '1.0.0')
      end
      true
    end

    Oregano::ModuleTool::Tar.expects(:instance).returns(untar)

    Oregano::ModuleTool::Applications::Unpacker.run(filename, :target_dir => target)
    expect(File).to be_directory(File.join(target, 'mytarball'))
  end

  it "should warn about symlinks", :if => Oregano.features.manages_symlinks? do
    untar = mock('Tar')
    untar.expects(:unpack).with(filename, anything()) do |src, dest, _|
      FileUtils.mkdir(File.join(dest, 'extractedmodule'))
      File.open(File.join(dest, 'extractedmodule', 'metadata.json'), 'w+') do |file|
        file.puts JSON.generate('name' => module_name, 'version' => '1.0.0')
      end
      FileUtils.touch(File.join(dest, 'extractedmodule/tempfile'))
      Oregano::FileSystem.symlink(File.join(dest, 'extractedmodule/tempfile'), File.join(dest, 'extractedmodule/tempfile2'))
      true
    end

    Oregano::ModuleTool::Tar.expects(:instance).returns(untar)
    Oregano.expects(:warning).with(regexp_matches(/symlinks/i))

    Oregano::ModuleTool::Applications::Unpacker.run(filename, :target_dir => target)
    expect(File).to be_directory(File.join(target, 'mytarball'))
  end

  it "should warn about symlinks in subdirectories", :if => Oregano.features.manages_symlinks? do
    untar = mock('Tar')
    untar.expects(:unpack).with(filename, anything()) do |src, dest, _|
      FileUtils.mkdir(File.join(dest, 'extractedmodule'))
      File.open(File.join(dest, 'extractedmodule', 'metadata.json'), 'w+') do |file|
        file.puts JSON.generate('name' => module_name, 'version' => '1.0.0')
      end
      FileUtils.mkdir(File.join(dest, 'extractedmodule/manifests'))
      FileUtils.touch(File.join(dest, 'extractedmodule/manifests/tempfile'))
      Oregano::FileSystem.symlink(File.join(dest, 'extractedmodule/manifests/tempfile'), File.join(dest, 'extractedmodule/manifests/tempfile2'))
      true
    end

    Oregano::ModuleTool::Tar.expects(:instance).returns(untar)
    Oregano.expects(:warning).with(regexp_matches(/symlinks/i))

    Oregano::ModuleTool::Applications::Unpacker.run(filename, :target_dir => target)
    expect(File).to be_directory(File.join(target, 'mytarball'))
  end
end
