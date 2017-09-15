require 'oregano/pops'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module ParserRspecHelper
  include FactoryRspecHelper

  def parse(code)
    parser = Oregano::Pops::Parser::Parser.new()
    parser.parse_string(code)
  end

  def parse_epp(code)
    parser = Oregano::Pops::Parser::EppParser.new()
    parser.parse_string(code)
  end
end
