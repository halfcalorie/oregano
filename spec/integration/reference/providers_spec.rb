#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/util/reference'

reference = Oregano::Util::Reference.reference(:providers)

describe reference do
  it "should exist" do
    expect(reference).not_to be_nil
  end

  it "should be able to be rendered as markdown" do
    reference.to_markdown
  end
end
