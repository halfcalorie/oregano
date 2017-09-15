require 'spec_helper'
require 'matchers/include_in_order'
require 'oregano_spec/compiler'
require 'oregano/indirector/catalog/compiler'

describe "A catalog" do
  include OreganoSpec::Compiler

  context "when compiled" do
    let(:env) { Oregano::Node::Environment.create(:testing, []) }
    let(:node) { Oregano::Node.new('test', :environment => env) }
    let(:loaders) { Oregano::Pops::Loaders.new(env) }

    around :each do |example|
      Oregano::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
      Oregano.override(:loaders => loaders, :current_environment => env) do
        example.run
        Oregano::Pops::Loaders.clear
      end
    end

    context "when transmitted to the agent" do

      it "preserves the order in which the resources are added to the catalog" do
        resources_in_declaration_order = ["Class[First]",
                                          "Second[position]",
                                          "Class[Third]",
                                          "Fourth[position]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
          define fourth() { }
          class third { }

          define second() {
            fourth { "position": }
          }

          class first {
            second { "position": }
            class { "third": }
          }

          include first
        EOM

        expect(resources_in(master_catalog)).
          to include_in_order(*resources_in_declaration_order)
        expect(resources_in(agent_catalog)).
          to include_in_order(*resources_in_declaration_order)
      end

      it "does not contain unrealized, virtual resources" do
        virtual_resources = ["Unrealized[unreal]", "Class[Unreal]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
          class unreal { }
          define unrealized() { }

          class real {
            @unrealized { "unreal": }
            @class { "unreal": }
          }

          include real
        EOM

        expect(resources_in(master_catalog)).to_not include(*virtual_resources)
        expect(resources_in(agent_catalog)).to_not include(*virtual_resources)
      end

      it "does not contain unrealized, exported resources" do
        exported_resources = ["Unrealized[unreal]", "Class[Unreal]"]

        master_catalog, agent_catalog = master_and_agent_catalogs_for(<<-EOM)
          class unreal { }
          define unrealized() { }

          class real {
            @@unrealized { "unreal": }
            @@class { "unreal": }
          }

          include real
        EOM

        expect(resources_in(master_catalog)).to_not include(*exported_resources)
        expect(resources_in(agent_catalog)).to_not include(*exported_resources)
      end
    end
  end

  def master_catalog_for(manifest)
    master_catalog = Oregano::Resource::Catalog::Compiler.new.filter(compile_to_catalog(manifest, node))
  end

  def master_and_agent_catalogs_for(manifest)
    compiler = Oregano::Resource::Catalog::Compiler.new
    master_catalog = compiler.filter(compile_to_catalog(manifest, node))
    agent_catalog = Oregano::Resource::Catalog.convert_from(:json, master_catalog.render(:json))
    [master_catalog, agent_catalog]
  end

  def resources_in(catalog)
    catalog.resources.map(&:ref)
  end
end
