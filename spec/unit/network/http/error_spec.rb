require 'spec_helper'
require 'matchers/json'

require 'oregano/network/http'

describe Oregano::Network::HTTP::Error do
  include JSONMatchers

  describe Oregano::Network::HTTP::Error::HTTPError do
    it "should serialize to JSON that matches the error schema" do
      error = Oregano::Network::HTTP::Error::HTTPError.new("I don't like the looks of you", 400, :SHIFTY_USER)

      expect(error.to_json).to validate_against('api/schemas/error.json')
    end
  end

  describe Oregano::Network::HTTP::Error::HTTPServerError do
    it "should serialize to JSON that matches the error schema" do
      begin
        raise Exception, "a wild Exception appeared!"
      rescue Exception => e
        culpable = e
      end
      error = Oregano::Network::HTTP::Error::HTTPServerError.new(culpable)

      expect(error.to_json).to validate_against('api/schemas/error.json')
    end
  end

end
