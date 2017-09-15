require 'spec_helper'
require 'oregano/util/profiler'

describe Oregano::Util::Profiler::ObjectCounts do
  it "reports the changes in the system object counts" do
    profiler = Oregano::Util::Profiler::ObjectCounts.new(nil, nil)

    message = profiler.finish(profiler.start)

    expect(message).to match(/ T_STRING: \d+, /)
  end
end
