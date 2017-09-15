require 'spec_helper'

require 'oregano/pops'
require 'oregano/pops/evaluator/evaluator_impl'
require 'oregano/loaders'
require 'oregano_spec/pops'
require 'oregano_spec/scope'
require 'oregano/parser/e4_parser_adapter'

describe 'Oregano::Pops::MigrationMigrationChecker' do
  include OreganoSpec::Pops
  include OreganoSpec::Scope
  before(:each) do
    Oregano[:strict_variables] = true

    # Oreganox cannot be loaded until the correct parser has been set (injector is turned off otherwise)
    require 'oregano_x'

    # Tests needs a known configuration of node/scope/compiler since it parses and evaluates
    # snippets as the compiler will evaluate them, butwithout the overhead of compiling a complete
    # catalog for each tested expression.
    #
    @parser  = Oregano::Pops::Parser::EvaluatingParser.new
    @node = Oregano::Node.new('node.example.com')
    @node.environment = Oregano::Node::Environment.create(:testing, [])
    @compiler = Oregano::Parser::Compiler.new(@node)
    @scope = Oregano::Parser::Scope.new(@compiler)
    @scope.source = Oregano::Resource::Type.new(:node, 'node.example.com')
    @scope.parent = @compiler.topscope
  end

  let(:scope) { @scope }

  describe "when there is no MigrationChecker in the OreganoContext" do
    it "a null implementation of the MigrationChecker gets created (once per impl that needs one)" do
      migration_checker = Oregano::Pops::Migration::MigrationChecker.new()
      Oregano::Pops::Migration::MigrationChecker.expects(:new).at_least_once.returns(migration_checker)
      expect(Oregano::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "1", __FILE__)).to eq(1)
      Oregano::Pops::Migration::MigrationChecker.unstub(:new)
    end
  end

  describe "when there is a MigrationChecker in the Oregano Context" do
    it "does not create any MigrationChecker instances when parsing and evaluating" do
      migration_checker = mock()
      Oregano::Pops::Migration::MigrationChecker.expects(:new).never
      Oregano.override({:migration_checker => migration_checker}, "test-context") do
        Oregano::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "true", __FILE__)
      end
      Oregano::Pops::Migration::MigrationChecker.unstub(:new)
    end
  end
end
