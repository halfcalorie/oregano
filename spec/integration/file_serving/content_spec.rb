#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/file_serving/content'

describe Oregano::FileServing::Content do
  it_should_behave_like "a file_serving model"
end
