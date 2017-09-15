require 'spec_helper'
require 'oregano/util/profiler'

describe Oregano::Util::Profiler::WallClock do

  it "logs the number of seconds it took to execute the segment" do
    profiler = Oregano::Util::Profiler::WallClock.new(nil, nil)

    message = profiler.do_finish(profiler.start(["foo", "bar"], "Testing"), ["foo", "bar"], "Testing")[:msg]

    expect(message).to match(/took \d\.\d{4} seconds/)
  end
end
