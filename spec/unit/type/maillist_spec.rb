#! /usr/bin/env ruby
require 'spec_helper'

maillist = Oregano::Type.type(:maillist)

describe maillist do
  before do
    @provider_class = Oregano::Type.type(:maillist).provider(:mailman)

    @provider = stub 'provider', :class => @provider_class, :clear => nil
    @provider.stubs(:respond_to).with(:aliases).returns(true)

    @provider_class.stubs(:new).returns(@provider)

    Oregano::Type.type(:maillist).stubs(:defaultprovider).returns(@provider_class)

    @maillist = Oregano::Type.type(:maillist).new( :name => 'test' )

    @catalog = Oregano::Resource::Catalog.new
    @maillist.catalog = @catalog
  end

  it "should generate aliases unless they already exist" do
    # Mail List aliases are careful not to stomp on managed Mail Alias aliases

    # test1 is an unmanaged alias from /etc/aliases
    Oregano::Type.type(:mailalias).provider(:aliases).stubs(:target_object).returns( StringIO.new("test1: root\n") )

    # test2 is a managed alias from the manifest
    dupe = Oregano::Type.type(:mailalias).new( :name => 'test2' )
    @catalog.add_resource dupe

    @provider.stubs(:aliases).returns({"test1" => 'this will get included', "test2" => 'this will dropped', "test3" => 'this will get included'})

    generated = @maillist.generate
    expect(generated.map{ |x| x.name  }.sort).to eq(['test1', 'test3'])
    expect(generated.map{ |x| x.class }).to      eq([Oregano::Type::Mailalias, Oregano::Type::Mailalias])

  end

end
