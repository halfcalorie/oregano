require 'erb'
require 'ostruct'
require 'fileutils'
require 'json'

class Benchmarker
  include FileUtils

  def initialize(target, size)
    @target = target
    @size = 200
  end

  def setup
    require 'oregano'
    config = File.join(@target, 'oregano.conf')
    Oregano.initialize_settings(['--config', config])
  end

  def run(args=nil)
    env = Oregano.lookup(:environments).get('benchmarking')
    node = Oregano::Node.new("testing", :environment => env)
    Oregano::Resource::Catalog.indirection.find("testing", :use_node => node)
  end

  def generate
    environment = File.join(@target, 'environments', 'benchmarking')
    templates = File.join('benchmarks', 'virtual_collection')

    mkdir_p(File.join(environment, 'modules'))
    mkdir_p(File.join(environment, 'manifests'))

    render(File.join(templates, 'site.pp.erb'),
           File.join(environment, 'manifests', 'site.pp'),
           :size => @size)

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
