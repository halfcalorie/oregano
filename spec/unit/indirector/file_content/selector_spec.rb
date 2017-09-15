#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_content/selector'

describe Oregano::Indirector::FileContent::Selector do
  include OreganoSpec::Files

  it_should_behave_like "Oregano::FileServing::Files", :file_content
end
