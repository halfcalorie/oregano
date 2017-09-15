# encoding: UTF-8

require 'spec_helper'
require 'oregano/face'
require 'oregano/module_tool'
require 'oregano_spec/modules'

describe "oregano module list" do
  include OreganoSpec::Files

  around do |example|
    dir = tmpdir("deep_path")

    FileUtils.mkdir_p(@modpath1 = File.join(dir, "modpath1"))
    FileUtils.mkdir_p(@modpath2 = File.join(dir, "modpath2"))
    FileUtils.mkdir_p(@modpath3 = File.join(dir, "modpath3"))

    env = Oregano::Node::Environment.create(:env, [@modpath1, @modpath2])
    Oregano.override(:current_environment => env) do
      example.run
    end
  end

  it "should return an empty list per dir in path if there are no modules" do
    expect(Oregano::Face[:module, :current].list[:modules_by_path]).to eq({
      @modpath1 => [],
      @modpath2 => []
    })
  end

  it "should include modules separated by the environment's modulepath" do
    foomod1 = OreganoSpec::Modules.create('foo', @modpath1)
    barmod1 = OreganoSpec::Modules.create('bar', @modpath1)
    foomod2 = OreganoSpec::Modules.create('foo', @modpath2)

    usedenv = Oregano::Node::Environment.create(:useme, [@modpath1, @modpath2, @modpath3])

    Oregano.override(:environments => Oregano::Environments::Static.new(usedenv)) do
      expect(Oregano::Face[:module, :current].list(:environment => 'useme')[:modules_by_path]).to eq({
        @modpath1 => [
          Oregano::Module.new('bar', barmod1.path, usedenv),
          Oregano::Module.new('foo', foomod1.path, usedenv)
        ],
        @modpath2 => [Oregano::Module.new('foo', foomod2.path, usedenv)],
        @modpath3 => [],
      })
    end
  end

  it "should use the specified environment" do
    foomod = OreganoSpec::Modules.create('foo', @modpath1)
    barmod = OreganoSpec::Modules.create('bar', @modpath1)

    usedenv = Oregano::Node::Environment.create(:useme, [@modpath1, @modpath2, @modpath3])

    Oregano.override(:environments => Oregano::Environments::Static.new(usedenv)) do
      expect(Oregano::Face[:module, :current].list(:environment => 'useme')[:modules_by_path]).to eq({
        @modpath1 => [
          Oregano::Module.new('bar', barmod.path, usedenv),
          Oregano::Module.new('foo', foomod.path, usedenv)
        ],
        @modpath2 => [],
        @modpath3 => [],
      })
    end
  end

  it "should use the specified modulepath" do
    foomod = OreganoSpec::Modules.create('foo', @modpath1)
    barmod = OreganoSpec::Modules.create('bar', @modpath2)

    modules = Oregano::Face[:module, :current].list(:modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}")[:modules_by_path]

    expect(modules[@modpath1].first.name).to eq('foo')
    expect(modules[@modpath1].first.path).to eq(foomod.path)
    expect(modules[@modpath1].first.environment.modulepath).to eq([@modpath1, @modpath2])

    expect(modules[@modpath2].first.name).to eq('bar')
    expect(modules[@modpath2].first.path).to eq(barmod.path)
    expect(modules[@modpath2].first.environment.modulepath).to eq([@modpath1, @modpath2])
  end

  it "prefers a given modulepath over the modulepath from the given environment" do
    foomod = OreganoSpec::Modules.create('foo', @modpath1)
    barmod = OreganoSpec::Modules.create('bar', @modpath2)
    env = Oregano::Node::Environment.create(:myenv, ['/tmp/notused'])

    modules = Oregano::Face[:module, :current].list(:environment => 'myenv', :modulepath => "#{@modpath1}#{File::PATH_SEPARATOR}#{@modpath2}")[:modules_by_path]

    expect(modules[@modpath1].first.name).to eq('foo')
    expect(modules[@modpath1].first.path).to eq(foomod.path)
    expect(modules[@modpath1].first.environment.modulepath).to eq([@modpath1, @modpath2])
    expect(modules[@modpath1].first.environment.name).to_not eq(:myenv)

    expect(modules[@modpath2].first.name).to eq('bar')
    expect(modules[@modpath2].first.path).to eq(barmod.path)
    expect(modules[@modpath2].first.environment.modulepath).to eq([@modpath1, @modpath2])
    expect(modules[@modpath2].first.environment.name).to_not eq(:myenv)
  end

  describe "inline documentation" do
    subject { Oregano::Face[:module, :current].get_action(:list) }

    its(:summary)     { should =~ /list.*module/im }
    its(:description) { should =~ /list.*module/im }
    its(:returns)     { should =~ /hash of paths to module objects/i }
    its(:examples)    { should_not be_empty }
  end

  describe "when rendering to console" do
    let(:face) { Oregano::Face[:module, :current] }
    let(:action) { face.get_action(:list) }

    def console_output(options={})
      result = face.list(options)
      action.when_rendering(:console).call(result, options)
    end

    it "should explicitly state when a modulepath is empty" do
      empty_modpath = tmpdir('empty')

      expected = <<-HEREDOC.gsub('        ', '')
        #{empty_modpath} (no modules installed)
      HEREDOC

      expect(console_output(:modulepath => empty_modpath)).to eq(expected)
    end

    it "should print both modules with and without metadata" do
      modpath = tmpdir('modpath')

      OreganoSpec::Modules.create('nometadata', modpath)
      OreganoSpec::Modules.create('metadata', modpath, :metadata => {:author => 'metaman'})

      env = Oregano::Node::Environment.create(:environ, [modpath])
      Oregano.override(:current_environment => env) do
        expected = <<-HEREDOC.gsub('          ', '')
          #{modpath}
          ├── metaman-metadata (\e[0;36mv9.9.9\e[0m)
          └── nometadata (\e[0;36m???\e[0m)
        HEREDOC

        expect(console_output).to eq(expected)
      end
    end

    it "should print the modulepaths in the order they are in the modulepath setting" do
      path1 = tmpdir('b')
      path2 = tmpdir('c')
      path3 = tmpdir('a')

      env = Oregano::Node::Environment.create(:environ, [path1, path2, path3])
      Oregano.override(:current_environment => env) do
        expected = <<-HEREDOC.gsub('          ', '')
          #{path1} (no modules installed)
          #{path2} (no modules installed)
          #{path3} (no modules installed)
        HEREDOC

        expect(console_output).to eq(expected)
      end
    end

    it "should print dependencies as a tree" do
      OreganoSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '0.0.5'})
      OreganoSpec::Modules.create(
        'other_mod',
        @modpath1,
        :metadata => {
          :version => '1.0.0',
          :dependencies => [{
            "version_requirement" => ">= 0.0.5",
            "name"                => "oreganolabs/dependable"
          }]
        }
      )

      expected = <<-HEREDOC.gsub('        ', '')
        #{@modpath1}
        └─┬ oreganolabs-other_mod (\e[0;36mv1.0.0\e[0m)
          └── oreganolabs-dependable (\e[0;36mv0.0.5\e[0m)
        #{@modpath2} (no modules installed)
      HEREDOC

      expect(console_output(:tree => true)).to eq(expected)
    end

    it "should print both modules with and without metadata as a tree" do
      OreganoSpec::Modules.create('nometadata', @modpath1)
      OreganoSpec::Modules.create('metadata', @modpath1, :metadata => {:author => 'metaman'})

      expected = <<-HEREDOC.gsub('        ', '')
        #{@modpath1}
        ├── metaman-metadata (\e[0;36mv9.9.9\e[0m)
        └── nometadata (\e[0;36m???\e[0m)
        #{@modpath2} (no modules installed)
      HEREDOC

      expect(console_output).to eq(expected)
    end

    it "should warn about missing dependencies" do
      OreganoSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "oreganolabs/dependable"
        }]
      })

      warning_expectations = [
        regexp_matches(/Missing dependency 'oreganolabs-dependable'/),
        regexp_matches(/'oreganolabs-depender' \(v1\.0\.0\) requires 'oreganolabs-dependable' \(>= 0\.0\.5\)/)
      ]

      Oregano.expects(:warning).with(all_of(*warning_expectations))

      console_output(:tree => true)
    end

    it 'should not warn about dependent module with pre-release version by default' do
      OreganoSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 1.0.0",
          "name"                => "oreganolabs/dependable"
        }]
      })
      OreganoSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '1.0.0-rc1' })

      expected = <<-OUTPUT.unindent
      #{@modpath1}
      ├── oreganolabs-dependable (\e[0;36mv1.0.0-rc1\e[0m)
      └── oreganolabs-depender (\e[0;36mv1.0.0\e[0m)
      #{@modpath2} (no modules installed)
      OUTPUT

      expect(console_output).to eq(expected)
    end

    it 'should warn about dependent module with pre-release version by if pre-release is less than given pre-release' do
      OreganoSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 1.0.0-rc1",
          "name"                => "oreganolabs/dependable"
        }]
      })
      OreganoSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '1.0.0-rc0' })

      expected = <<-OUTPUT.unindent
      #{@modpath1}
      ├── oreganolabs-dependable (\e[0;36mv1.0.0-rc0\e[0m)  \e[0;31minvalid\e[0m
      └── oreganolabs-depender (\e[0;36mv1.0.0\e[0m)
      #{@modpath2} (no modules installed)
      OUTPUT

      expect(console_output).to eq(expected)
    end

    it 'should warn about dependent module with pre-release version when using strict SemVer' do
      OreganoSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 1.0.0",
          "name"                => "oreganolabs/dependable"
        }]
      })
      OreganoSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '1.0.0-rc1' })

      expected = <<-OUTPUT.unindent
      #{@modpath1}
      ├── oreganolabs-dependable (\e[0;36mv1.0.0-rc1\e[0m)  \e[0;31minvalid\e[0m
      └── oreganolabs-depender (\e[0;36mv1.0.0\e[0m)
      #{@modpath2} (no modules installed)
      OUTPUT

      expect(console_output(:strict_semver => true)).to eq(expected)
    end

    it "should warn about out of range dependencies" do
      OreganoSpec::Modules.create('dependable', @modpath1, :metadata => { :version => '0.0.1'})
      OreganoSpec::Modules.create('depender', @modpath1, :metadata => {
        :version => '1.0.0',
        :dependencies => [{
          "version_requirement" => ">= 0.0.5",
          "name"                => "oreganolabs/dependable"
        }]
      })

      warning_expectations = [
        regexp_matches(/Module 'oreganolabs-dependable' \(v0\.0\.1\) fails to meet some dependencies/),
        regexp_matches(/'oreganolabs-depender' \(v1\.0\.0\) requires 'oreganolabs-dependable' \(>= 0\.0\.5\)/)
      ]

      Oregano.expects(:warning).with(all_of(*warning_expectations))

      console_output(:tree => true)
    end
  end
end
