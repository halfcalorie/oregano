require 'spec_helper'
require 'oregano/pops'
require 'oregano/loaders'

describe 'the match function' do

  before(:all) do
    loaders = Oregano::Pops::Loaders.new(Oregano::Node::Environment.create(:testing, []))
    Oregano.push_context({:loaders => loaders}, "test-examples")
  end

  after(:all) do
    Oregano::Pops::Loaders.clear
    Oregano::pop_context()
  end

  let(:func) do
    Oregano.lookup(:loaders).oregano_system_loader.load(:function, 'match')
  end

  let(:type_parser) { Oregano::Pops::Types::TypeParser.singleton }


  it 'matches string and regular expression without captures' do
    expect(func.call({}, 'abc123', /[a-z]+[1-9]+/)).to eql(['abc123'])
  end

  it 'matches string and regular expression with captures' do
    expect(func.call({}, 'abc123', /([a-z]+)([1-9]+)/)).to eql(['abc123', 'abc', '123'])
  end

  it 'produces nil if match is not found' do
    expect(func.call({}, 'abc123', /([x]+)([6]+)/)).to be_nil
  end

  [ 'Pattern[/([a-z]+)([1-9]+)/]',       # regexp
    'Pattern["([a-z]+)([1-9]+)"]',       # string
    'Regexp[/([a-z]+)([1-9]+)/]',        # regexp type
    'Pattern[/x9/, /([a-z]+)([1-9]+)/]', # regexp, first found matches
  ].each do |pattern|
    it "matches string and type #{pattern} with captures" do
      expect(func.call({}, 'abc123', type(pattern))).to eql(['abc123', 'abc', '123'])
    end
  end

  it 'matches an array of strings and yields a map of the result' do
    expect(func.call({}, ['abc123', '2a', 'xyz2'], /([a-z]+)[1-9]+/)).to eql([['abc123', 'abc'], nil, ['xyz2', 'xyz']])
  end

  it 'raises error if Regexp type without regexp is used' do
    expect{func.call({}, 'abc123', type('Regexp'))}.to raise_error(ArgumentError, /Given Regexp Type has no regular expression/)
  end

  def type(s)
    Oregano::Pops::Types::TypeParser.singleton.parse(s)
  end
end
