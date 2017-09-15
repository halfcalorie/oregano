require 'spec_helper'
require 'oregano/pops'
require 'oregano/parser/parser_factory'
require 'oregano_spec/compiler'
require 'oregano_spec/pops'
require 'oregano_spec/scope'
require 'matchers/resource'

# These tests are in a separate file since othr compiler related tests have
# been dramatically changed between 3.x and 4.x and it is a pain to merge
# them.
#
describe "Oregano::Parser::Compiler when dealing with relative naming" do
  include OreganoSpec::Compiler
  include Matchers::Resource

  describe "the compiler when using 4.x parser and evaluator" do
    it "should use absolute references even if references are not anchored" do
      node = Oregano::Node.new("testnodex")
      catalog = compile_to_catalog(<<-PP, node)
      class foo::thing {
        notify {"from foo::thing":}
      }

      class thing {
        notify {"from ::thing":}
      }

      class foo {
      #  include thing
        class {'thing':}
      }

      include foo
      PP

      catalog = Oregano::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[from ::thing]")
    end

    it "should use absolute references when references are absolute" do
      node = Oregano::Node.new("testnodex")
      catalog = compile_to_catalog(<<-PP, node)
      class foo::thing {
        notify {"from foo::thing":}
      }

      class thing {
        notify {"from ::thing":}
      }

      class foo {
      #  include thing
        class {'::thing':}
      }

      include foo
      PP

      catalog = Oregano::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[from ::thing]")
    end
  end
end
