#! /usr/bin/env ruby
require 'spec_helper'

require 'oregano/indirector/node/ldap'

describe Oregano::Node::Ldap do
  it "should use a restrictive filter when searching for nodes in a class" do
    ldap = Oregano::Node.indirection.terminus(:ldap)
    Oregano::Node.indirection.stubs(:terminus).returns ldap
    ldap.expects(:ldapsearch).with("(&(objectclass=oreganoClient)(oreganoclass=foo))")

    Oregano::Node.indirection.search "eh", :class => "foo"
  end
end
