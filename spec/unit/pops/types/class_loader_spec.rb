require 'spec_helper'
require 'oregano/pops'

describe 'the Oregano::Pops::Types::ClassLoader' do
  it 'should produce path alternatives for CamelCase classes' do
    expected_paths = ['oregano_x/some_thing', 'oreganox/something']
    # path_for_name method is private
    expect(Oregano::Pops::Types::ClassLoader.send(:paths_for_name, ['OreganoX', 'SomeThing'])).to include(*expected_paths)
  end
end
