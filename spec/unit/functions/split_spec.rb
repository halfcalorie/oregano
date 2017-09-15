require 'spec_helper'
require 'oregano/pops'
require 'oregano/loaders'

describe 'the split function' do

  before(:all) do
    loaders = Oregano::Pops::Loaders.new(Oregano::Node::Environment.create(:testing, []))
    Oregano.push_context({:loaders => loaders}, "test-examples")
  end

  after(:all) do
    Oregano::Pops::Loaders.clear
    Oregano::pop_context()
  end

  def split(*args)
    Oregano.lookup(:loaders).oregano_system_loader.load(:function, 'split').call({}, *args)
  end

  let(:type_parser) { Oregano::Pops::Types::TypeParser.singleton }

  it 'should raise an Error if there is less than 2 arguments' do
    expect { split('a,b') }.to raise_error(/'split' expects 2 arguments, got 1/)
  end

  it 'should raise an Error if there is more than 2 arguments' do
    expect { split('a,b','foo', 'bar') }.to raise_error(/'split' expects 2 arguments, got 3/)
  end

  it 'should raise a RegexpError if the regexp is malformed' do
    expect { split('a,b',')') }.to raise_error(/unmatched close parenthesis/)
  end

  it 'should handle pattern in string form' do
    expect(split('a,b',',')).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp form' do
    expect(split('a,b',/,/)).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form' do
    expect(split('a,b',type_parser.parse('Regexp[/,/]'))).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form with empty regular expression' do
    expect(split('ab',type_parser.parse('Regexp[//]'))).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form with missing regular expression' do
    expect(split('ab',type_parser.parse('Regexp'))).to eql(['a', 'b'])
  end
end
