require 'spec_helper'
require 'oregano_spec/scope'

describe 'Oregano::Parser::Functions#hiera_hash' do
  include OreganoSpec::Scope

  let :scope do create_test_scope_for_node('foo') end

  it 'should raise an error since this function is converted to 4x API)' do
    expect { scope.function_hiera_hash(['key']) }.to raise_error(Oregano::ParseError, /can only be called using the 4.x function API/)
  end
end
