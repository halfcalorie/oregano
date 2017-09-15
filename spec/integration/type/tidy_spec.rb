#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano_spec/compiler'
require 'oregano_spec/files'
require 'oregano/file_bucket/dipper'

describe Oregano::Type.type(:tidy) do
  include OreganoSpec::Files
  include OreganoSpec::Compiler

  before do
    Oregano::Util::Storage.stubs(:store)
  end

  it "should be able to recursively remove directories" do
    dir = tmpfile("tidy_testing")
    FileUtils.mkdir_p(File.join(dir, "foo", "bar"))

    apply_compiled_manifest(<<-MANIFEST)
      tidy { '#{dir}':
        recurse => true,
        rmdirs  => true,
      }
    MANIFEST

    expect(Oregano::FileSystem.directory?(dir)).to be_falsey
  end

  # Testing #355.
  it "should be able to remove dead links", :if => Oregano.features.manages_symlinks? do
    dir = tmpfile("tidy_link_testing")
    link = File.join(dir, "link")
    target = tmpfile("no_such_file_tidy_link_testing")
    Dir.mkdir(dir)
    Oregano::FileSystem.symlink(target, link)

    apply_compiled_manifest(<<-MANIFEST)
      tidy { '#{dir}':
        recurse => true,
      }
    MANIFEST

    expect(Oregano::FileSystem.symlink?(link)).to be_falsey
  end
end
