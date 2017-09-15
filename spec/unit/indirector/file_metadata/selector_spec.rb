#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/file_metadata/selector'

describe Oregano::Indirector::FileMetadata::Selector do
  include OreganoSpec::Files

  it_should_behave_like "Oregano::FileServing::Files", :file_metadata
end

