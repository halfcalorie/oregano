require 'fileutils'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = size > 1000 ? size : 1000
  end

  def setup
    require 'oregano'
    @config = File.join(@target, 'oregano.conf')
    Oregano.initialize_settings(['--config', @config])
    envs = Oregano.lookup(:environments)
    @node = Oregano::Node.new('testing', :environment => envs.get('benchmarking'))
  end

  def run(args=nil)
    @size.times do
      @compiler = Oregano::Parser::Compiler.new(@node)
      @compiler.compile do |catalog|
        scope = @compiler.topscope
        scope['confdir'] = 'test'
          hiera_func = @compiler.loaders.oregano_system_loader.load(:function, 'hiera_include')
          hiera_func.call(scope, 'common_entry')
        catalog
      end
    end
  end

  def generate
    env_dir = File.join(@target, 'environments', 'benchmarking')
    manifests_dir = File.join(env_dir, 'manifests')
    dummy_class_manifest = File.join(manifests_dir, 'foo.pp')
    hiera_yaml = File.join(@target, 'hiera.yaml')
    datadir = File.join(@target, 'data')
    localdir = File.dirname(File.realpath(__FILE__))
    common_yaml = File.join(datadir, 'common.yaml')
    groups_yaml = File.join(datadir, 'groups.yaml')

    mkdir_p(env_dir)
    mkdir_p(manifests_dir)
    mkdir_p(datadir)

    File.open(hiera_yaml, 'w') do |f|
      f.puts(<<-YAML)
---
:backends: yaml
:yaml:
   :datadir: #{datadir}
:hierarchy:
   - common
   - groups
:logger: noop
      YAML
    end

    File.open(groups_yaml, 'w') do |f|
      f.puts(<<-YAML)
---
oregano:
  staff:
    groups:
      YAML

      0.upto(50).each do |i|
        f.puts("      group#{i}:")
        0.upto(125).each do |j|
          f.puts("        - user#{j}")
        end
      end
    end

    File.open(dummy_class_manifest, 'w') do |f|
      f.puts("class dummy_class { }")
    end

    File.open(common_yaml, 'w') do |f|
      f.puts(<<-YAML)
        common_entry:
          - dummy_class
      YAML
    end

    templates = File.dirname(File.realpath(__FILE__))

    render(File.join(templates, 'oregano.conf.erb'),
      File.join(@target, 'oregano.conf'),
      :location => @target)
  end

  def render(erb_file, output_file, bindings)
    site = ERB.new(File.read(erb_file))
    File.open(output_file, 'w') do |fh|
      fh.write(site.result(OpenStruct.new(bindings).instance_eval { binding }))
    end
  end
end
