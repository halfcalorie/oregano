require 'oregano/pops'

module FactoryRspecHelper
  def literal(x)
    Oregano::Pops::Model::Factory.literal(x)
  end

  def block(*args)
    Oregano::Pops::Model::Factory.block(*args)
  end

  def var(x)
    Oregano::Pops::Model::Factory.var(x)
  end

  def fqn(x)
    Oregano::Pops::Model::Factory.fqn(x)
  end

  def string(*args)
    Oregano::Pops::Model::Factory.string(*args)
  end

  def minus(x)
    Oregano::Pops::Model::Factory.minus(x)
  end

  def IF(test, then_expr, else_expr=nil)
    Oregano::Pops::Model::Factory.IF(test, then_expr, else_expr)
  end

  def UNLESS(test, then_expr, else_expr=nil)
    Oregano::Pops::Model::Factory.UNLESS(test, then_expr, else_expr)
  end

  def CASE(test, *options)
    Oregano::Pops::Model::Factory.CASE(test, *options)
  end

  def WHEN(values, block)
    Oregano::Pops::Model::Factory.WHEN(values, block)
  end

  def method_missing(method, *args, &block)
    if Oregano::Pops::Model::Factory.respond_to? method
      Oregano::Pops::Model::Factory.send(method, *args, &block)
    else
      super
    end
  end

  # i.e. Selector Entry 1 => 'hello'
  def MAP(match, value)
    Oregano::Pops::Model::Factory.MAP(match, value)
  end

  def dump(x)
    Oregano::Pops::Model::ModelTreeDumper.new.dump(x)
  end

  def unindent x
    (x.gsub /^#{x[/\A\s*/]}/, '').chomp
  end
  factory ||= Oregano::Pops::Model::Factory
end
