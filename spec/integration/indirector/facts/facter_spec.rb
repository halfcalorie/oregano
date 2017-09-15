#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano_spec/files'
require 'oregano_spec/compiler'

describe Oregano::Node::Facts::Facter do
  include OreganoSpec::Files
  include OreganoSpec::Compiler

  it "preserves case in fact values" do
    Facter.add(:downcase_test) do
      setcode do
        "AaBbCc"
      end
    end

    Facter.stubs(:reset)

    cat = compile_to_catalog('notify { $downcase_test: }',
                             Oregano::Node.indirection.find('foo'))
    expect(cat.resource("Notify[AaBbCc]")).to be
  end

  context "resolving file based facts" do
    let(:factdir) { tmpdir('factdir') }

    it "should resolve custom facts" do
      test_module = File.join(factdir, 'module', 'lib', 'facter')
      FileUtils.mkdir_p(test_module)

      File.open(File.join(test_module, 'custom.rb'), 'wb') { |file| file.write(<<-EOF)}
      Facter.add(:custom) do
        setcode do
          Facter.value('oreganoversion')
        end
      end
      EOF

      Oregano.initialize_settings(['--modulepath', factdir])
      apply = Oregano::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => ['--modulepath', factdir, '-e', 'notify { $custom: }']))

      expect do
        expect { apply.run }.to exit_with(0)
      end.to have_printed(Oregano.version)
    end

    it "should resolve external facts" do
      external_fact = File.join(factdir, 'external')

      if Oregano.features.microsoft_windows?
        external_fact += '.bat'
        File.open(external_fact, 'wb') { |file| file.write(<<-EOF)}
        @echo foo=bar
        EOF
      else
        File.open(external_fact, 'wb') { |file| file.write(<<-EOF)}
        #!/bin/sh
        echo "foo=bar"
        EOF

        Oregano::FileSystem.chmod(0755, external_fact)
      end

      Oregano.initialize_settings(['--pluginfactdest', factdir])
      apply = Oregano::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => ['--pluginfactdest', factdir, '-e', 'notify { $foo: }']))

      expect do
        expect { apply.run }.to exit_with(0)
      end.to have_printed('bar')
    end
  end

  it "adds the oreganoversion fact" do
    Facter.stubs(:reset)

    cat = compile_to_catalog('notify { $::oreganoversion: }',
                             Oregano::Node.indirection.find('foo'))
    expect(cat.resource("Notify[#{Oregano.version.to_s}]")).to be
  end

  it "the agent_specified_environment fact is nil when not set" do
    expect do
      compile_to_catalog('notify { $::agent_specified_environment: }',
                         Oregano::Node.indirection.find('foo'))
    end.to raise_error(Oregano::PreformattedError)
  end

  it "adds the agent_specified_environment fact when set in oregano.conf" do
    FileUtils.mkdir_p(Oregano[:confdir])
    File.open(File.join(Oregano[:confdir], 'oregano.conf'), 'w') do |f|
      f.puts("environment=bar")
    end

    Oregano.initialize_settings
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Oregano::Node.indirection.find('foo'))
    expect(cat.resource("Notify[bar]")).to be
  end

  it "adds the agent_specified_environment fact when set via command-line" do
    Oregano.initialize_settings(['--environment', 'bar'])
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Oregano::Node.indirection.find('foo'))
    expect(cat.resource("Notify[bar]")).to be
  end

  it "adds the agent_specified_environment fact, preferring cli, when set in oregano.conf and via command-line" do
    FileUtils.mkdir_p(Oregano[:confdir])
    File.open(File.join(Oregano[:confdir], 'oregano.conf'), 'w') do |f|
      f.puts("environment=bar")
    end

    Oregano.initialize_settings(['--environment', 'baz'])
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Oregano::Node.indirection.find('foo'))
    expect(cat.resource("Notify[baz]")).to be
  end
end
