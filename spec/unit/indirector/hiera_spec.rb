require 'spec_helper'
require 'oregano/data_binding'
require 'oregano/indirector/hiera'
require 'hiera/backend'

describe Oregano::Indirector::Hiera do

  module Testing
    module DataBinding
      class Hiera < Oregano::Indirector::Hiera
      end
    end
  end

  it_should_behave_like "Hiera indirection", Testing::DataBinding::Hiera, my_fixture_dir
end

