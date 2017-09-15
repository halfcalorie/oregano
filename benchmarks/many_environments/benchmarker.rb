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
  end

  def run(args=nil)
    Oregano.settings.clear
    environment_loaders = Oregano.lookup(:environments)
    environment_loaders.clear_all
    environment_loaders.get!("anenv#{@size/2}")
  end

  def generate
    environments = File.join(@target, 'environments')
    oregano_conf = File.join(@target, 'oregano.conf')

    File.open(oregano_conf, 'w') do |f|
      f.puts(<<-EOF)
        environmentpath=#{environments}
      EOF
    end

    @size.times do |i|
      mkdir_p(File.join(environments, "anenv#{i}"))
    end
  end
end
