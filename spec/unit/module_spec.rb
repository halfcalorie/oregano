#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano_spec/files'
require 'oregano_spec/modules'
require 'oregano/module_tool/checksums'

describe Oregano::Module do
  include OreganoSpec::Files

  let(:env) { mock("environment") }
  let(:path) { "/path" }
  let(:name) { "mymod" }
  let(:mod) { Oregano::Module.new(name, path, env) }

  before do
    # This is necessary because of the extra checks we have for the deprecated
    # 'plugins' directory
    Oregano::FileSystem.stubs(:exist?).returns false
  end

  it "should have a class method that returns a named module from a given environment" do
    env = Oregano::Node::Environment.create(:myenv, [])
    env.expects(:module).with(name).returns "yep"
    Oregano.override(:environments => Oregano::Environments::Static.new(env)) do
      expect(Oregano::Module.find(name, "myenv")).to eq("yep")
    end
  end

  it "should return nil if asked for a named module that doesn't exist" do
    env = Oregano::Node::Environment.create(:myenv, [])
    env.expects(:module).with(name).returns nil
    Oregano.override(:environments => Oregano::Environments::Static.new(env)) do
      expect(Oregano::Module.find(name, "myenv")).to be_nil
    end
  end

  describe "is_module_directory?" do
    let(:first_modulepath) { tmpdir('firstmodules') }
    let(:not_a_module) { tmpfile('thereisnomodule', first_modulepath) }

    it "should return false for a non-directory" do
      expect(Oregano::Module.is_module_directory?('thereisnomodule', first_modulepath)).to be_falsey
    end

    it "should return true for a well named directories" do
      OreganoSpec::Modules.generate_files('foo', first_modulepath)
      OreganoSpec::Modules.generate_files('foo2', first_modulepath)
      OreganoSpec::Modules.generate_files('foo_bar', first_modulepath)
      expect(Oregano::Module.is_module_directory?('foo', first_modulepath)).to be_truthy
      expect(Oregano::Module.is_module_directory?('foo2', first_modulepath)).to be_truthy
      expect(Oregano::Module.is_module_directory?('foo_bar', first_modulepath)).to be_truthy
    end

    it "should return false for badly named directories" do
      OreganoSpec::Modules.generate_files('foo=bar', first_modulepath)
      OreganoSpec::Modules.generate_files('.foo', first_modulepath)
      expect(Oregano::Module.is_module_directory?('foo=bar', first_modulepath)).to be_falsey
      expect(Oregano::Module.is_module_directory?('.foo', first_modulepath)).to be_falsey
    end
  end

  describe "is_module_directory_name?" do
    it "should return true for a valid directory module name" do
      expect(Oregano::Module.is_module_directory_name?('foo')).to be_truthy
      expect(Oregano::Module.is_module_directory_name?('foo2')).to be_truthy
      expect(Oregano::Module.is_module_directory_name?('foo_bar')).to be_truthy
    end

    it "should return false for badly formed directory module names" do
      expect(Oregano::Module.is_module_directory_name?('foo-bar')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('foo=bar')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('foo bar')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('foo.bar')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('-foo')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('foo-')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('foo--bar')).to be_falsey
      expect(Oregano::Module.is_module_directory_name?('.foo')).to be_falsey
    end
  end

  describe "is_module_namespaced_name?" do
    it "should return true for a valid namespaced module name" do
      expect(Oregano::Module.is_module_namespaced_name?('foo-bar')).to be_truthy
    end

    it "should return false for badly formed namespaced module names" do
      expect(Oregano::Module.is_module_namespaced_name?('foo')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('.foo-bar')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo2')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo_bar')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo=bar')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo bar')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo.bar')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('-foo')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo-')).to be_falsey
      expect(Oregano::Module.is_module_namespaced_name?('foo--bar')).to be_falsey
    end
  end

  describe "attributes" do
    it "should support a 'version' attribute" do
      mod.version = 1.09
      expect(mod.version).to eq(1.09)
    end

    it "should support a 'source' attribute" do
      mod.source = "http://foo/bar"
      expect(mod.source).to eq("http://foo/bar")
    end

    it "should support a 'project_page' attribute" do
      mod.project_page = "http://foo/bar"
      expect(mod.project_page).to eq("http://foo/bar")
    end

    it "should support an 'author' attribute" do
      mod.author = "Luke Kanies <luke@madstop.com>"
      expect(mod.author).to eq("Luke Kanies <luke@madstop.com>")
    end

    it "should support a 'license' attribute" do
      mod.license = "GPL2"
      expect(mod.license).to eq("GPL2")
    end

    it "should support a 'summary' attribute" do
      mod.summary = "GPL2"
      expect(mod.summary).to eq("GPL2")
    end

    it "should support a 'description' attribute" do
      mod.description = "GPL2"
      expect(mod.description).to eq("GPL2")
    end
  end

  describe "when finding unmet dependencies" do
    before do
      Oregano::FileSystem.unstub(:exist?)
      @modpath = tmpdir('modpath')
      Oregano.settings[:modulepath] = @modpath
    end

    it "should resolve module dependencies using forge names" do
      parent = OreganoSpec::Modules.create(
        'parent',
        @modpath,
        :metadata => {
          :author => 'foo',
          :dependencies => [{
            "name" => "foo/child"
          }]
        },
        :environment => env
      )
      child = OreganoSpec::Modules.create(
        'child',
        @modpath,
        :metadata => {
          :author => 'foo',
          :dependencies => []
        },
        :environment => env
      )

      env.expects(:module_by_forge_name).with('foo/child').returns(child)

      expect(parent.unmet_dependencies).to eq([])
    end

    it "should list modules that are missing" do
      metadata_file = "#{@modpath}/needy/metadata.json"
      mod = OreganoSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )

      env.expects(:module_by_forge_name).with('baz/foobar').returns(nil)

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'oreganolabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }])
    end

    it "should list modules that are missing and have invalid names" do
      metadata_file = "#{@modpath}/needy/metadata.json"
      mod = OreganoSpec::Modules.create(
        'needy',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar=bar"
          }]
        },
        :environment => env
      )

      env.expects(:module_by_forge_name).with('baz/foobar=bar').returns(nil)

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :name   => "baz/foobar=bar",
        :version_constraint => ">= 2.2.0",
        :parent => { :name => 'oreganolabs/needy', :version => 'v9.9.9' },
        :mod_details => { :installed_version => nil }
      }])
    end

    it "should list modules with unmet version requirement" do
      env = Oregano::Node::Environment.create(:testing, [@modpath])

      ['test_gte_req', 'test_specific_req', 'foobar'].each do |mod_name|
        mod_dir = "#{@modpath}/#{mod_name}"
        metadata_file = "#{mod_dir}/metadata.json"
        tasks_dir = "#{mod_dir}/tasks"
        Oregano::FileSystem.stubs(:exist?).with(metadata_file).returns true
      end
      mod = OreganoSpec::Modules.create(
        'test_gte_req',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      mod2 = OreganoSpec::Modules.create(
        'test_specific_req',
        @modpath,
        :metadata => {
          :dependencies => [{
            "version_requirement" => "1.0.0",
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )

      OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => { :version => '2.0.0', :author  => 'baz' },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => ">= 2.2.0",
        :parent => { :version => "v9.9.9", :name => "oreganolabs/test_gte_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }])

      expect(mod2.unmet_dependencies).to eq([{
        :reason => :version_mismatch,
        :name   => "baz/foobar",
        :version_constraint => "v1.0.0",
        :parent => { :version => "v9.9.9", :name => "oreganolabs/test_specific_req" },
        :mod_details => { :installed_version => "2.0.0" }
      }])

    end

    it "should consider a dependency without a version requirement to be satisfied" do
      env = Oregano::Node::Environment.create(:testing, [@modpath])

      mod = OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => [{
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :version => '2.0.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to be_empty
    end

    it "should consider a dependency without a semantic version to be unmet" do
      env = Oregano::Node::Environment.create(:testing, [@modpath])

      metadata_file = "#{@modpath}/foobar/metadata.json"
      mod = OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => [{
            "name" => "baz/foobar"
          }]
        },
        :environment => env
      )
      OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :version => '5.1',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :non_semantic_version,
        :parent => { :version => "v9.9.9", :name => "oreganolabs/foobar" },
        :mod_details => { :installed_version => "5.1" },
        :name => "baz/foobar",
        :version_constraint => ">= 0.0.0"
      }])
    end

    it "should have valid dependencies when no dependencies have been specified" do
      mod = OreganoSpec::Modules.create(
        'foobar',
        @modpath,
        :metadata => {
          :dependencies => []
        }
      )

      expect(mod.unmet_dependencies).to eq([])
    end

    it "should throw an error if invalid dependencies are specified" do
      expect {
        OreganoSpec::Modules.create(
          'foobar',
          @modpath,
          :metadata => {
            :dependencies => ""
          }
        )
      }.to raise_error(
        Oregano::Module::MissingMetadata,
        /dependencies in the file metadata.json of the module foobar must be an array, not: ''/)
    end

    it "should only list unmet dependencies" do
      env = Oregano::Node::Environment.create(:testing, [@modpath])

      mod = OreganoSpec::Modules.create(
        name,
        @modpath,
        :metadata => {
          :dependencies => [
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/satisfied"
            },
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/notsatisfied"
            }
          ]
        },
        :environment => env
      )
      OreganoSpec::Modules.create(
        'satisfied',
        @modpath,
        :metadata => {
          :version => '3.3.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to eq([{
        :reason => :missing,
        :mod_details => { :installed_version => nil },
        :parent => { :version => "v9.9.9", :name => "oreganolabs/#{name}" },
        :name => "baz/notsatisfied",
        :version_constraint => ">= 2.2.0"
      }])
    end

    it "should be empty when all dependencies are met" do
      env = Oregano::Node::Environment.create(:testing, [@modpath])

      mod = OreganoSpec::Modules.create(
        'mymod2',
        @modpath,
        :metadata => {
          :dependencies => [
            {
              "version_requirement" => ">= 2.2.0",
              "name" => "baz/satisfied"
            },
            {
              "version_requirement" => "< 2.2.0",
              "name" => "baz/alsosatisfied"
            }
          ]
        },
        :environment => env
      )
      OreganoSpec::Modules.create(
        'satisfied',
        @modpath,
        :metadata => {
          :version => '3.3.0',
          :author  => 'baz'
        },
        :environment => env
      )
      OreganoSpec::Modules.create(
        'alsosatisfied',
        @modpath,
        :metadata => {
          :version => '2.1.0',
          :author  => 'baz'
        },
        :environment => env
      )

      expect(mod.unmet_dependencies).to be_empty
    end
  end


  describe "initialize_i18n" do

    let(:modpath) { tmpdir('modpath') }
    let(:modname) { 'oreganolabs-i18n'}
    let(:modroot) { "#{modpath}/#{modname}/" }
    let(:config_path) { "#{modroot}/locales/config.yaml" }
    let(:mod_obj) { OreganoSpec::Modules.create( modname, modpath, :metadata => { :dependencies => [] }, :env => env ) }

    it "is expected to initialize an un-initialized module" do
      expect(GettextSetup.translation_repositories.has_key? modname).to be false

      FileUtils.mkdir_p("#{mod_obj.path}/locales")
      config = {
        "gettext" => {
          "project_name" => modname
        }
      }
      File.open(config_path, 'w') { |file| file.write(config.to_yaml) }

      mod_obj.initialize_i18n

      expect(GettextSetup.translation_repositories.has_key? modname).to be true
    end
    it "is expected return nil if module is intiailized" do
      expect(mod_obj.initialize_i18n).to be nil
    end
  end

  describe "when managing supported platforms" do
    it "should support specifying a supported platform" do
      mod.supports "solaris"
    end

    it "should support specifying a supported platform and version" do
      mod.supports "solaris", 1.0
    end
  end

  it "should return nil if asked for a module whose name is 'nil'" do
    expect(Oregano::Module.find(nil, "myenv")).to be_nil
  end

  it "should provide support for logging" do
    expect(Oregano::Module.ancestors).to be_include(Oregano::Util::Logging)
  end

  it "should be able to be converted to a string" do
    expect(mod.to_s).to eq("Module #{name}(#{path})")
  end

  it "should fail if its name is not alphanumeric" do
    expect { Oregano::Module.new(".something", "/path", env) }.to raise_error(Oregano::Module::InvalidName)
  end

  it "should require a name at initialization" do
    expect { Oregano::Module.new }.to raise_error(ArgumentError)
  end

  it "should accept an environment at initialization" do
    expect(Oregano::Module.new("foo", "/path", env).environment).to eq(env)
  end

  describe '#modulepath' do
    it "should return the directory the module is installed in, if a path exists" do
      mod = Oregano::Module.new("foo", "/a/foo", env)
      expect(mod.modulepath).to eq('/a')
    end
  end

  [:plugins, :pluginfacts, :templates, :files, :manifests].each do |filetype|
    case filetype
      when :plugins
        dirname = "lib"
      when :pluginfacts
        dirname = "facts.d"
      else
        dirname = filetype.to_s
    end
    it "should be able to return individual #{filetype}" do
      module_file = File.join(path, dirname, "my/file")
      Oregano::FileSystem.expects(:exist?).with(module_file).returns true
      expect(mod.send(filetype.to_s.sub(/s$/, ''), "my/file")).to eq(module_file)
    end

    it "should consider #{filetype} to be present if their base directory exists" do
      module_file = File.join(path, dirname)
      Oregano::FileSystem.expects(:exist?).with(module_file).returns true
      expect(mod.send(filetype.to_s + "?")).to be_truthy
    end

    it "should consider #{filetype} to be absent if their base directory does not exist" do
      module_file = File.join(path, dirname)
      Oregano::FileSystem.expects(:exist?).with(module_file).returns false
      expect(mod.send(filetype.to_s + "?")).to be_falsey
    end

    it "should return nil if asked to return individual #{filetype} that don't exist" do
      module_file = File.join(path, dirname, "my/file")
      Oregano::FileSystem.expects(:exist?).with(module_file).returns false
      expect(mod.send(filetype.to_s.sub(/s$/, ''), "my/file")).to be_nil
    end

    it "should return the base directory if asked for a nil path" do
      base = File.join(path, dirname)
      Oregano::FileSystem.expects(:exist?).with(base).returns true
      expect(mod.send(filetype.to_s.sub(/s$/, ''), nil)).to eq(base)
    end
  end

  it "should return the path to the plugin directory" do
    expect(mod.plugin_directory).to eq(File.join(path, "lib"))
  end

  it "should return the path to the tasks directory" do
    expect(mod.tasks_directory).to eq(File.join(path, "tasks"))
  end

  describe "when finding tasks" do
    before do
      Oregano::FileSystem.unstub(:exist?)
      @modpath = tmpdir('modpath')
      Oregano.settings[:modulepath] = @modpath
    end

    it "should have an empty array for the tasks when the tasks directory does not exist" do
      mod = OreganoSpec::Modules.create('tasks_test_nodir', @modpath, :environment => env)
      expect(mod.tasks).to eq([])
    end

    it "should have an empty array for the tasks when the tasks directory does exist and is empty" do
      mod = OreganoSpec::Modules.create('tasks_test_empty', @modpath, {:environment => env,
                                                                      :tasks => []})
      expect(mod.tasks).to eq([])
    end

    it "should list the expected tasks when the required files exist" do
      fake_tasks = [['task1'], ['task2.sh', 'task2.json']]
      mod = OreganoSpec::Modules.create('tasks_smoke', @modpath, {:environment => env,
                                                                 :tasks => fake_tasks})

      expect(mod.tasks.count).to eq(2)
      expect(mod.tasks.map{|t| t.name}.sort).to eq(['tasks_smoke::task1', 'tasks_smoke::task2'])
      expect(mod.tasks.map{|t| t.class}).to eq([Oregano::Module::Task] * 2)
    end

    it "should be able to find individual task files when they exist" do
      task_exe = 'stateskatetask.stk'
      mod = OreganoSpec::Modules.create('task_file_smoke', @modpath, {:environment => env,
                                                                     :tasks => [[task_exe]]})

      expect(mod.task_file(task_exe)).to eq("#{mod.path}/tasks/#{task_exe}")
    end

    it "should return nil when asked for an individual task file if it does not exist" do
      mod = OreganoSpec::Modules.create('task_file_neg', @modpath, {:environment => env,
                                                                   :tasks => []})
      expect(mod.task_file('nosuchtask')).to be_nil
    end

    describe "does the task finding" do
      before :each do
        Oregano::FileSystem.unstub(:exist?)
        Oregano::Module::Task.unstub(:tasks_in_module)
      end

      let(:mod_name) { 'tasks_test_lazy' }
      let(:mod_tasks_dir) { File.join(@modpath, mod_name, 'tasks') }

      it "after the module is initialized" do
        Oregano::FileSystem.expects(:exist?).with(mod_tasks_dir).never
        Oregano::Module::Task.expects(:tasks_in_module).never
        Oregano::Module.new(mod_name, @modpath, env)
      end

      it "when the tasks method is called" do
        Oregano::Module::Task.expects(:tasks_in_module)
        mod = OreganoSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :tasks => [['itascanstaccatotask']]})
        mod.tasks
      end

      it "only once for the lifetime of the module object" do
        Dir.expects(:glob).with("#{mod_tasks_dir}/*").once.returns ['allalaskataskattacktactics']
        mod = OreganoSpec::Modules.create(mod_name, @modpath, {:environment => env,
                                                              :tasks => []})
        mod.tasks
        mod.tasks
      end
    end
  end
end

describe Oregano::Module, "when finding matching manifests" do
  before do
    @mod = Oregano::Module.new("mymod", "/a", mock("environment"))
    @pq_glob_with_extension = "yay/*.xx"
    @fq_glob_with_extension = "/a/manifests/#{@pq_glob_with_extension}"
  end

  it "should return all manifests matching the glob pattern" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{foo bar})
    FileTest.stubs(:directory?).returns false

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{foo bar})
  end

  it "should not return directories" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{foo bar})

    FileTest.expects(:directory?).with("foo").returns false
    FileTest.expects(:directory?).with("bar").returns true
    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{foo})
  end

  it "should default to the 'init' file if no glob pattern is specified" do
    Oregano::FileSystem.expects(:exist?).with("/a/manifests/init.pp").returns(true)

    expect(@mod.match_manifests(nil)).to eq(%w{/a/manifests/init.pp})
  end

  it "should return all manifests matching the glob pattern in all existing paths" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns(%w{a b})

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq(%w{a b})
  end

  it "should match the glob pattern plus '.pp' if no extension is specified" do
    Dir.expects(:glob).with("/a/manifests/yay/foo.pp").returns(%w{yay})

    expect(@mod.match_manifests("yay/foo")).to eq(%w{yay})
  end

  it "should return an empty array if no manifests matched" do
    Dir.expects(:glob).with(@fq_glob_with_extension).returns([])

    expect(@mod.match_manifests(@pq_glob_with_extension)).to eq([])
  end

  it "should raise an error if the pattern tries to leave the manifest directory" do
    expect do
      @mod.match_manifests("something/../../*")
    end.to raise_error(Oregano::Module::InvalidFilePattern, 'The pattern "something/../../*" to find manifests in the module "mymod" is invalid and potentially unsafe.')
  end
end

describe Oregano::Module do
  include OreganoSpec::Files

  let!(:modpath) do
    path = tmpdir('modpath')
    OreganoSpec::Modules.create('mymod', path)
    path
  end

  let!(:mymodpath) { File.join(modpath, 'mymod') }

  let!(:mymod_metadata) { File.join(mymodpath, 'metadata.json') }

  let(:mymod) { Oregano::Module.new('mymod', mymodpath, nil) }

  it "should use 'License' in its current path as its metadata file" do
    expect(mymod.license_file).to eq("#{modpath}/mymod/License")
  end

  it "should cache the license file" do
    mymod.expects(:path).once.returns nil
    mymod.license_file
    mymod.license_file
  end

  it "should use 'metadata.json' in its current path as its metadata file" do
    expect(mymod_metadata).to eq("#{modpath}/mymod/metadata.json")
  end

  it "should not have metadata if it has a metadata file and its data is valid but empty json hash" do
    File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns "{}"

    expect(mymod).not_to be_has_metadata
  end

  it "should not have metadata if it has a metadata file and its data is empty" do
    File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns ""

    expect(mymod).not_to be_has_metadata
  end

  it "should not have metadata if has a metadata file and its data is invalid" do
    File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns "This is some invalid json.\n"
    expect(mymod).not_to be_has_metadata
  end

  it "should know if it is missing a metadata file" do
    File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).raises(Errno::ENOENT)

    expect(mymod).not_to be_has_metadata
  end

  it "should be able to parse its metadata file" do
    expect(mymod).to respond_to(:load_metadata)
  end

  it "should parse its metadata file on initialization if it is present" do
    Oregano::Module.any_instance.expects(:load_metadata)

    Oregano::Module.new("yay", "/path", mock("env"))
  end

  it "should tolerate failure to parse" do
    File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns(my_fixture('trailing-comma.json'))

    expect(mymod.has_metadata?).to be_falsey
  end

  describe 'when --strict is warning' do
    before :each do
      Oregano[:strict] = :warning
    end

    it "should warn about a failure to parse" do
      File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns(my_fixture('trailing-comma.json'))

      expect(mymod.has_metadata?).to be_falsey
      expect(@logs).to have_matching_log(/mymod has an invalid and unparsable metadata\.json file/)
    end
  end

    describe 'when --strict is off' do
      before :each do
        Oregano[:strict] = :off
      end

      it "should not warn about a failure to parse" do
        File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns(my_fixture('trailing-comma.json'))

        expect(mymod.has_metadata?).to be_falsey
        expect(@logs).to_not have_matching_log(/mymod has an invalid and unparsable metadata\.json file.*/)
      end

      it "should log debug output about a failure to parse when --debug is on" do
        Oregano[:log_level] = :debug
        File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns(my_fixture('trailing-comma.json'))

        expect(mymod.has_metadata?).to be_falsey
        expect(@logs).to have_matching_log(/mymod has an invalid and unparsable metadata\.json file.*/)
      end
    end

    describe 'when --strict is error' do
      before :each do
        Oregano[:strict] = :error
      end

      it "should fail on a failure to parse" do
        File.stubs(:read).with(mymod_metadata, {:encoding => 'utf-8'}).returns(my_fixture('trailing-comma.json'))

        expect do
        expect(mymod.has_metadata?).to be_falsey
        end.to raise_error(/mymod has an invalid and unparsable metadata\.json file/)
      end
    end

  def a_module_with_metadata(data)
    File.stubs(:read).with("/path/metadata.json", {:encoding => 'utf-8'}).returns data.to_json
    Oregano::Module.new("foo", "/path", mock("env"))
  end

  describe "when loading the metadata file" do
    let(:data) do
      {
        :license       => "GPL2",
        :author        => "luke",
        :version       => "1.0",
        :source        => "http://foo/",
        :dependencies  => []
      }
    end

    %w{source author version license}.each do |attr|
      it "should set #{attr} if present in the metadata file" do
        mod = a_module_with_metadata(data)
        expect(mod.send(attr)).to eq(data[attr.to_sym])
      end

      it "should fail if #{attr} is not present in the metadata file" do
        data.delete(attr.to_sym)
        expect { a_module_with_metadata(data) }.to raise_error(
          Oregano::Module::MissingMetadata,
          "No #{attr} module metadata provided for foo"
        )
      end
    end
  end

  describe "when loading the metadata file from disk" do
    it "should properly parse utf-8 contents" do
      rune_utf8 = "\u16A0\u16C7\u16BB" # ᚠᛇᚻ
      metadata_json = tmpfile('metadata.json')
      File.open(metadata_json, 'w:UTF-8') do |file|
        file.puts <<-EOF
  {
    "license" : "GPL2",
    "author" : "#{rune_utf8}",
    "version" : "1.0",
    "source" : "http://foo/",
    "dependencies" : []
  }
        EOF
      end

      Oregano::Module.any_instance.stubs(:metadata_file).returns metadata_json
      mod = Oregano::Module.new('foo', '/path', mock('env'))

      mod.load_metadata
      expect(mod.author).to eq(rune_utf8)
    end
  end

  it "should be able to tell if there are local changes" do
    modpath = tmpdir('modpath')
    foo_checksum = 'acbd18db4cc2f85cedef654fccc4a4d8'
    checksummed_module = OreganoSpec::Modules.create(
      'changed',
      modpath,
      :metadata => {
        :checksums => {
          "foo" => foo_checksum,
        }
      }
    )

    foo_path = Pathname.new(File.join(checksummed_module.path, 'foo'))

    IO.binwrite(foo_path, 'notfoo')
    expect(Oregano::ModuleTool::Checksums.new(foo_path).checksum(foo_path)).not_to eq(foo_checksum)

    IO.binwrite(foo_path, 'foo')
    expect(Oregano::ModuleTool::Checksums.new(foo_path).checksum(foo_path)).to eq(foo_checksum)
  end

  it "should know what other modules require it" do
    env = Oregano::Node::Environment.create(:testing, [modpath])

    dependable = OreganoSpec::Modules.create(
      'dependable',
      modpath,
      :metadata => {:author => 'oreganolabs'},
      :environment => env
    )
    OreganoSpec::Modules.create(
      'needy',
      modpath,
      :metadata => {
        :author => 'beggar',
        :dependencies => [{
            "version_requirement" => ">= 2.2.0",
            "name" => "oreganolabs/dependable"
        }]
      },
      :environment => env
    )
    OreganoSpec::Modules.create(
      'wantit',
      modpath,
      :metadata => {
        :author => 'spoiled',
        :dependencies => [{
            "version_requirement" => "< 5.0.0",
            "name" => "oreganolabs/dependable"
        }]
      },
      :environment => env
    )
    expect(dependable.required_by).to match_array([
      {
        "name"    => "beggar/needy",
        "version" => "9.9.9",
        "version_requirement" => ">= 2.2.0"
      },
      {
        "name"    => "spoiled/wantit",
        "version" => "9.9.9",
        "version_requirement" => "< 5.0.0"
      }
    ])
  end

  context 'when parsing VersionRange' do
    let(:logs) { [] }
    let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }

    it 'can parse a strict range' do
      expect(Oregano::Module.parse_range('>=1.0.0', true).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_falsey
    end

    it 'can parse a non-strict range' do
      expect(Oregano::Module.parse_range('>=1.0.0', false).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_truthy
    end

    context 'using parse method with an arity of 1' do
      around(:each) do |example|
        begin
          example.run
        ensure
          Oregano::Module.instance_variable_set(:@semver_gem_version, nil)
          Oregano::Module.instance_variable_set(:@parse_range_method, nil)
        end
      end

      it 'will notify when non-strict ranges cannot be parsed' do
        Oregano::Module.instance_variable_set(:@semver_gem_version, SemanticOregano::Version.parse('1.0.0'))
        Oregano::Module.instance_variable_set(:@parse_range_method, Proc.new { |str| SemanticOregano::VersionRange.parse(str, true) })

        Oregano::Util::Log.with_destination(Oregano::Test::LogCollector.new(logs)) do
          expect(Oregano::Module.parse_range('>=1.0.0', false).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_falsey
        end
        expect(notices).to include(/VersionRanges will always be strict when using non-vendored SemanticOregano gem, version 1\.0\.0/)
      end

      it 'will notify when strict ranges cannot be parsed' do
        Oregano::Module.instance_variable_set(:@semver_gem_version, SemanticOregano::Version.parse('0.1.4'))
        Oregano::Module.instance_variable_set(:@parse_range_method, Proc.new { |str| SemanticOregano::VersionRange.parse(str, false) })

        Oregano::Util::Log.with_destination(Oregano::Test::LogCollector.new(logs)) do
          expect(Oregano::Module.parse_range('>=1.0.0', true).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_truthy
        end
        expect(notices).to include(/VersionRanges will never be strict when using non-vendored SemanticOregano gem, version 0\.1\.4/)
      end

      it 'will not notify when strict ranges can be parsed' do
        Oregano::Module.instance_variable_set(:@semver_gem_version, SemanticOregano::Version.parse('1.0.0'))
        Oregano::Module.instance_variable_set(:@parse_range_method, Proc.new { |str| SemanticOregano::VersionRange.parse(str, true) })

        Oregano::Util::Log.with_destination(Oregano::Test::LogCollector.new(logs)) do
          expect(Oregano::Module.parse_range('>=1.0.0', true).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_falsey
        end
        expect(notices).to be_empty
      end

      it 'will not notify when non-strict ranges can be parsed' do
        Oregano::Module.instance_variable_set(:@semver_gem_version, SemanticOregano::Version.parse('0.1.4'))
        Oregano::Module.instance_variable_set(:@parse_range_method, Proc.new { |str| SemanticOregano::VersionRange.parse(str, false) })

        Oregano::Util::Log.with_destination(Oregano::Test::LogCollector.new(logs)) do
          expect(Oregano::Module.parse_range('>=1.0.0', false).include?(SemanticOregano::Version.parse('1.0.1-rc1'))).to be_truthy
        end
        expect(notices).to be_empty
      end
    end
  end
end
