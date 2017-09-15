#! /usr/bin/env ruby
require 'spec_helper'

describe Oregano::Parser::Functions do
  def callable_functions_from(mod)
    Class.new { include mod }.new
  end

  let(:function_module) { Oregano::Parser::Functions.environment_module(Oregano.lookup(:current_environment)) }

  let(:environment) { Oregano::Node::Environment.create(:myenv, []) }

  before do
    Oregano::Parser::Functions.reset
  end

  it "should have a method for returning an environment-specific module" do
    expect(Oregano::Parser::Functions.environment_module(environment)).to be_instance_of(Module)
  end

  describe "when calling newfunction" do
    it "should create the function in the environment module" do
      Oregano::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }

      expect(function_module).to be_method_defined :function_name
    end

    it "should warn if the function already exists" do
      Oregano::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
      Oregano.expects(:warning)

      Oregano::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
    end

    it "should raise an error if the function type is not correct" do
      expect { Oregano::Parser::Functions.newfunction("name", :type => :unknown) { |args| } }.to raise_error Oregano::DevError, "Invalid statement type :unknown"
    end

    it "instruments the function to profile the execution" do
      messages = []
      Oregano::Util::Profiler.add_profiler(Oregano::Util::Profiler::WallClock.new(proc { |msg| messages << msg }, "id"))

      Oregano::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }
      callable_functions_from(function_module).function_name([])

      expect(messages.first).to match(/Called name/)
    end
  end

  describe "when calling function to test function existence" do
    it "should return false if the function doesn't exist" do
      Oregano::Parser::Functions.autoloader.stubs(:load)

      expect(Oregano::Parser::Functions.function("name")).to be_falsey
    end

    it "should return its name if the function exists" do
      Oregano::Parser::Functions.newfunction("name", :type => :rvalue) { |args| }

      expect(Oregano::Parser::Functions.function("name")).to eq("function_name")
    end

    it "should try to autoload the function if it doesn't exist yet" do
      Oregano::Parser::Functions.autoloader.expects(:load)

      Oregano::Parser::Functions.function("name")
    end

    it "combines functions from the root with those from the current environment" do
      Oregano.override(:current_environment => Oregano.lookup(:root_environment)) do
        Oregano::Parser::Functions.newfunction("onlyroot", :type => :rvalue) do |args|
        end
      end

      Oregano.override(:current_environment => Oregano::Node::Environment.create(:other, [])) do
        Oregano::Parser::Functions.newfunction("other_env", :type => :rvalue) do |args|
        end

        expect(Oregano::Parser::Functions.function("onlyroot")).to eq("function_onlyroot")
        expect(Oregano::Parser::Functions.function("other_env")).to eq("function_other_env")
      end

      expect(Oregano::Parser::Functions.function("other_env")).to be_falsey
    end
  end

  describe "when calling function to test arity" do
    let(:function_module) { Oregano::Parser::Functions.environment_module(Oregano.lookup(:current_environment)) }

    it "should raise an error if the function is called with too many arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      expect { callable_functions_from(function_module).function_name([1,2,3]) }.to raise_error ArgumentError
    end

    it "should raise an error if the function is called with too few arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      expect { callable_functions_from(function_module).function_name([1]) }.to raise_error ArgumentError
    end

    it "should not raise an error if the function is called with correct number of arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => 2) { |args| }
      expect { callable_functions_from(function_module).function_name([1,2]) }.to_not raise_error
    end

    it "should raise an error if the variable arg function is called with too few arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      expect { callable_functions_from(function_module).function_name([1]) }.to raise_error ArgumentError
    end

    it "should not raise an error if the variable arg function is called with correct number of arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      expect { callable_functions_from(function_module).function_name([1,2]) }.to_not raise_error
    end

    it "should not raise an error if the variable arg function is called with more number of arguments" do
      Oregano::Parser::Functions.newfunction("name", :arity => -3) { |args| }
      expect { callable_functions_from(function_module).function_name([1,2,3]) }.to_not raise_error
    end
  end

  describe "::arity" do
    it "returns the given arity of a function" do
      Oregano::Parser::Functions.newfunction("name", :arity => 4) { |args| }
      expect(Oregano::Parser::Functions.arity(:name)).to eq(4)
    end

    it "returns -1 if no arity is given" do
      Oregano::Parser::Functions.newfunction("name") { |args| }
      expect(Oregano::Parser::Functions.arity(:name)).to eq(-1)
    end
  end
end
