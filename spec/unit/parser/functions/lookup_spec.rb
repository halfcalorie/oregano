require 'spec_helper'
require 'oregano/pops'
require 'stringio'
require 'oregano_spec/scope'

describe "lookup function" do
  include OreganoSpec::Scope

  let :scope do create_test_scope_for_node('foo') end

  it 'should raise an error since this function is converted to 4x API)' do
    expect { scope.function_lookup(['key']) }.to raise_error(Oregano::ParseError, /can only be called using the 4.x function API/)
  end
end
