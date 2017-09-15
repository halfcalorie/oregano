#! /usr/bin/env ruby
require 'spec_helper'
require 'oregano/resource'

describe Oregano::Resource do
  include OreganoSpec::Files

  let(:basepath) { make_absolute("/somepath") }
  let(:environment) { Oregano::Node::Environment.create(:testing, []) }

  def expect_lookup(key)
    Oregano::Pops::Lookup::GlobalDataProvider.any_instance.expects(:unchecked_key_lookup).with(Oregano::Pops::Lookup::LookupKey.new(key), any_parameters)
  end

  [:catalog, :file, :line].each do |attr|
    it "should have an #{attr} attribute" do
      resource = Oregano::Resource.new("file", "/my/file")
      expect(resource).to respond_to(attr)
      expect(resource).to respond_to(attr.to_s + "=")
    end
  end

  it "should have a :title attribute" do
    expect(Oregano::Resource.new(:user, "foo").title).to eq("foo")
  end

  it "should require the type and title" do
    expect { Oregano::Resource.new }.to raise_error(ArgumentError)
  end

  it "should canonize types to capitalized strings" do
    expect(Oregano::Resource.new(:user, "foo").type).to eq("User")
  end

  it "should canonize qualified types so all strings are capitalized" do
    expect(Oregano::Resource.new("foo::bar", "foo").type).to eq("Foo::Bar")
  end

  it "should tag itself with its type" do
    expect(Oregano::Resource.new("file", "/f")).to be_tagged("file")
  end

  it "should tag itself with its title if the title is a valid tag" do
    expect(Oregano::Resource.new("user", "bar")).to be_tagged("bar")
  end

  it "should not tag itself with its title if the title is a not valid tag" do
    expect(Oregano::Resource.new("file", "/bar")).not_to be_tagged("/bar")
  end

  it "should allow setting of attributes" do
    expect(Oregano::Resource.new("file", "/bar", :file => "/foo").file).to eq("/foo")
    expect(Oregano::Resource.new("file", "/bar", :exported => true)).to be_exported
  end

  it "should set its type to 'Class' and its title to the passed title if the passed type is :component and the title has no square brackets in it" do
    ref = Oregano::Resource.new(:component, "foo")
    expect(ref.type).to eq("Class")
    expect(ref.title).to eq("Foo")
  end

  it "should interpret the title as a reference and assign appropriately if the type is :component and the title contains square brackets" do
    ref = Oregano::Resource.new(:component, "foo::bar[yay]")
    expect(ref.type).to eq("Foo::Bar")
    expect(ref.title).to eq("yay")
  end

  it "should set the type to 'Class' if it is nil and the title contains no square brackets" do
    ref = Oregano::Resource.new(nil, "yay")
    expect(ref.type).to eq("Class")
    expect(ref.title).to eq("Yay")
  end

  it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains square brackets" do
    ref = Oregano::Resource.new(nil, "foo::bar[yay]")
    expect(ref.type).to eq("Foo::Bar")
    expect(ref.title).to eq("yay")
  end

  it "should interpret the title as a reference and assign appropriately if the type is nil and the title contains nested square brackets" do
    ref = Oregano::Resource.new(nil, "foo::bar[baz[yay]]")
    expect(ref.type).to eq("Foo::Bar")
    expect(ref.title).to eq("baz[yay]")
  end

  it "should interpret the type as a reference and assign appropriately if the title is nil and the type contains square brackets" do
    ref = Oregano::Resource.new("foo::bar[baz]")
    expect(ref.type).to eq("Foo::Bar")
    expect(ref.title).to eq("baz")
  end

  it "should not interpret the title as a reference if the type is a non component or whit reference" do
    ref = Oregano::Resource.new("Notify", "foo::bar[baz]")
    expect(ref.type).to eq("Notify")
    expect(ref.title).to eq("foo::bar[baz]")
  end

  it "should be able to extract its information from a Oregano::Type instance" do
    ral = Oregano::Type.type(:file).new :path => basepath+"/foo"
    ref = Oregano::Resource.new(ral)
    expect(ref.type).to eq("File")
    expect(ref.title).to eq(basepath+"/foo")
  end


  it "should fail if the title is nil and the type is not a valid resource reference string" do
    expect { Oregano::Resource.new("resource-spec-foo") }.to raise_error(ArgumentError)
  end

  it 'should fail if strict is set and type does not exist' do
    expect { Oregano::Resource.new('resource-spec-foo', 'title', {:strict=>true}) }.to raise_error(ArgumentError, 'Invalid resource type resource-spec-foo')
  end

  it 'should fail if strict is set and class does not exist' do
    expect { Oregano::Resource.new('Class', 'resource-spec-foo', {:strict=>true}) }.to raise_error(ArgumentError, 'Could not find declared class resource-spec-foo')
  end

  it "should fail if the title is a hash and the type is not a valid resource reference string" do
    expect { Oregano::Resource.new({:type => "resource-spec-foo", :title => "bar"}) }.
      to raise_error ArgumentError, /Oregano::Resource.new does not take a hash/
  end

  it "should be taggable" do
    expect(Oregano::Resource.ancestors).to be_include(Oregano::Util::Tagging)
  end

  it "should have an 'exported' attribute" do
    resource = Oregano::Resource.new("file", "/f")
    resource.exported = true
    expect(resource.exported).to eq(true)
    expect(resource).to be_exported
  end

  describe "and munging its type and title" do
    describe "when modeling a builtin resource" do
      it "should be able to find the resource type" do
        expect(Oregano::Resource.new("file", "/my/file").resource_type).to equal(Oregano::Type.type(:file))
      end

      it "should set its type to the capitalized type name" do
        expect(Oregano::Resource.new("file", "/my/file").type).to eq("File")
      end
    end

    describe "when modeling a defined resource" do
      describe "that exists" do
        before do
          @type = Oregano::Resource::Type.new(:definition, "foo::bar")
          environment.known_resource_types.add @type
        end

        it "should set its type to the capitalized type name" do
          expect(Oregano::Resource.new("foo::bar", "/my/file", :environment => environment).type).to eq("Foo::Bar")
        end

        it "should be able to find the resource type" do
          expect(Oregano::Resource.new("foo::bar", "/my/file", :environment => environment).resource_type).to equal(@type)
        end

        it "should set its title to the provided title" do
          expect(Oregano::Resource.new("foo::bar", "/my/file", :environment => environment).title).to eq("/my/file")
        end
      end

      describe "that does not exist" do
        it "should set its resource type to the capitalized resource type name" do
          expect(Oregano::Resource.new("foo::bar", "/my/file").type).to eq("Foo::Bar")
        end
      end
    end

    describe "when modeling a node" do
      # Life's easier with nodes, because they can't be qualified.
      it "should set its type to 'Node' and its title to the provided title" do
        node = Oregano::Resource.new("node", "foo")
        expect(node.type).to eq("Node")
        expect(node.title).to eq("foo")
      end
    end

    describe "when modeling a class" do
      it "should set its type to 'Class'" do
        expect(Oregano::Resource.new("class", "foo").type).to eq("Class")
      end

      describe "that exists" do
        before do
          @type = Oregano::Resource::Type.new(:hostclass, "foo::bar")
          environment.known_resource_types.add @type
        end

        it "should set its title to the capitalized, fully qualified resource type" do
          expect(Oregano::Resource.new("class", "foo::bar", :environment => environment).title).to eq("Foo::Bar")
        end

        it "should be able to find the resource type" do
          expect(Oregano::Resource.new("class", "foo::bar", :environment => environment).resource_type).to equal(@type)
        end
      end

      describe "that does not exist" do
        it "should set its type to 'Class' and its title to the capitalized provided name" do
          klass = Oregano::Resource.new("class", "foo::bar")
          expect(klass.type).to eq("Class")
          expect(klass.title).to eq("Foo::Bar")
        end
      end

      describe "and its name is set to the empty string" do
        it "should set its title to :main" do
          expect(Oregano::Resource.new("class", "").title).to eq(:main)
        end

        describe "and a class exists whose name is the empty string" do # this was a bit tough to track down
          it "should set its title to :main" do
            @type = Oregano::Resource::Type.new(:hostclass, "")
            environment.known_resource_types.add @type

            expect(Oregano::Resource.new("class", "", :environment => environment).title).to eq(:main)
          end
        end
      end

      describe "and its name is set to :main" do
        it "should set its title to :main" do
          expect(Oregano::Resource.new("class", :main).title).to eq(:main)
        end

        describe "and a class exists whose name is the empty string" do # this was a bit tough to track down
          it "should set its title to :main" do
            @type = Oregano::Resource::Type.new(:hostclass, "")
            environment.known_resource_types.add @type

            expect(Oregano::Resource.new("class", :main, :environment => environment).title).to eq(:main)
          end
        end
      end
    end
  end

  it "should return nil when looking up resource types that don't exist" do
    expect(Oregano::Resource.new("foobar", "bar").resource_type).to be_nil
  end

  it "should not fail when an invalid parameter is used and strict mode is disabled" do
    type = Oregano::Resource::Type.new(:definition, "foobar")
    environment.known_resource_types.add type
    resource = Oregano::Resource.new("foobar", "/my/file", :environment => environment)
    resource[:yay] = true
  end

  it "should be considered equivalent to another resource if their type and title match and no parameters are set" do
    expect(Oregano::Resource.new("file", "/f")).to eq(Oregano::Resource.new("file", "/f"))
  end

  it "should be considered equivalent to another resource if their type, title, and parameters are equal" do
    expect(Oregano::Resource.new("file", "/f", :parameters => {:foo => "bar"})).to eq(Oregano::Resource.new("file", "/f", :parameters => {:foo => "bar"}))
  end

  it "should not be considered equivalent to another resource if their type and title match but parameters are different" do
    expect(Oregano::Resource.new("file", "/f", :parameters => {:fee => "baz"})).not_to eq(Oregano::Resource.new("file", "/f", :parameters => {:foo => "bar"}))
  end

  it "should not be considered equivalent to a non-resource" do
    expect(Oregano::Resource.new("file", "/f")).not_to eq("foo")
  end

  it "should not be considered equivalent to another resource if their types do not match" do
    expect(Oregano::Resource.new("file", "/f")).not_to eq(Oregano::Resource.new("exec", "/f"))
  end

  it "should not be considered equivalent to another resource if their titles do not match" do
    expect(Oregano::Resource.new("file", "/foo")).not_to eq(Oregano::Resource.new("file", "/f"))
  end

  describe "when setting default parameters" do
    let(:foo_node) { Oregano::Node.new('foo', :environment => environment) }
    let(:compiler) { Oregano::Parser::Compiler.new(foo_node) }
    let(:scope)    { Oregano::Parser::Scope.new(compiler) }

    def ast_leaf(value)
      Oregano::Parser::AST::Leaf.new({:value => value})
    end

    it "should fail when asked to set default values and it is not a parser resource" do
      environment.known_resource_types.add(
      Oregano::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_leaf("default")})
      )
      resource = Oregano::Resource.new("default_param", "name", :environment => environment)
      expect { resource.set_default_parameters(scope) }.to raise_error(Oregano::DevError)
    end

    it "should evaluate and set any default values when no value is provided" do
      environment.known_resource_types.add(
        Oregano::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_leaf("a_default_value")})
      )
      resource = Oregano::Parser::Resource.new("default_param", "name", :scope => scope)
      resource.set_default_parameters(scope)
      expect(resource["a"]).to eq("a_default_value")
    end

    it "should skip attributes with no default value" do
      environment.known_resource_types.add(
        Oregano::Resource::Type.new(:definition, "no_default_param", :arguments => {"a" => ast_leaf("a_default_value")})
      )
      resource = Oregano::Parser::Resource.new("no_default_param", "name", :scope => scope)
      expect { resource.set_default_parameters(scope) }.not_to raise_error
    end

    it "should return the list of default parameters set" do
      environment.known_resource_types.add(
        Oregano::Resource::Type.new(:definition, "default_param", :arguments => {"a" => ast_leaf("a_default_value")})
      )
      resource = Oregano::Parser::Resource.new("default_param", "name", :scope => scope)
      expect(resource.set_default_parameters(scope)).to eq(["a"])
    end

    describe "when the resource type is :hostclass" do
      let(:environment_name) { "testing env" }
      let(:fact_values) { { :a => 1 } }
      let(:port) { Oregano::Parser::AST::Leaf.new(:value => '80') }

      def inject_and_set_defaults(resource, scope)
        resource.resource_type.set_resource_parameters(resource, scope)
      end

      before do
        environment.known_resource_types.add(apache)

        scope.stubs(:host).returns('host')
        scope.stubs(:environment).returns(environment)
        scope.stubs(:facts).returns(Oregano::Node::Facts.new("facts", fact_values))
      end

      context 'with a default value expression' do
        let(:apache) { Oregano::Resource::Type.new(:hostclass, 'apache', :arguments => { 'port' => port }) }

        context "when no value is provided" do
          let(:resource) do
            Oregano::Parser::Resource.new("class", "apache", :scope => scope)
          end

          it "should query the data_binding terminus using a namespaced key" do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port')
            inject_and_set_defaults(resource, scope)
          end

          it "should use the value from the data_binding terminus" do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port').returns('443')

            inject_and_set_defaults(resource, scope)

            expect(resource[:port]).to eq('443')
          end

          it 'should use the default value if no value is found using the data_binding terminus' do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port').throws(:no_such_key)

            inject_and_set_defaults(resource, scope)

            expect(resource[:port]).to eq('80')
          end

          it 'should use the default value if an undef value is found using the data_binding terminus' do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port').returns(nil)

            inject_and_set_defaults(resource, scope)

            expect(resource[:port]).to eq('80')
          end

          it "should fail with error message about data binding on a hiera failure" do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port').raises(Oregano::DataBinding::LookupError, 'Forgettabotit')
            expect {
              inject_and_set_defaults(resource, scope)
            }.to raise_error(Oregano::Error, /Lookup of key 'apache::port' failed: Forgettabotit/)
          end
        end

        context "when a value is provided" do
          let(:port_parameter) do
            Oregano::Parser::Resource::Param.new(
              { :name => 'port', :value => '8080' }
            )
          end

          let(:resource) do
            Oregano::Parser::Resource.new("class", "apache", :scope => scope,
              :parameters => [port_parameter])
          end

          it "should not query the data_binding terminus" do
            Oregano::DataBinding.indirection.expects(:find).never
            inject_and_set_defaults(resource, scope)
          end

          it "should use the value provided" do
            Oregano::DataBinding.indirection.expects(:find).never
            expect(resource.set_default_parameters(scope)).to eq([])
            expect(resource[:port]).to eq('8080')
          end

          it "should use the value from the data_binding terminus when provided value is undef" do
            expect_lookup('lookup_options').throws(:no_such_key)
            expect_lookup('apache::port').returns('443')

            rs = Oregano::Parser::Resource.new("class", "apache", :scope => scope,
              :parameters => [Oregano::Parser::Resource::Param.new({ :name => 'port', :value => nil })])

            rs.resource_type.set_resource_parameters(rs, scope)
            expect(rs[:port]).to eq('443')
          end
        end
      end

      context 'without a default value expression' do
        let(:apache) { Oregano::Resource::Type.new(:hostclass, 'apache', :arguments => { 'port' => nil }) }
        let(:resource) { Oregano::Parser::Resource.new("class", "apache", :scope => scope) }

        it "should use the value from the data_binding terminus" do
          expect_lookup('lookup_options').throws(:no_such_key)
          expect_lookup('apache::port').returns('443')

          inject_and_set_defaults(resource, scope)

          expect(resource[:port]).to eq('443')
        end

        it "should use an undef value from the data_binding terminus" do
          expect_lookup('lookup_options').throws(:no_such_key)
          expect_lookup('apache::port').returns(nil)

          inject_and_set_defaults(resource, scope)

          expect(resource[:port]).to be_nil
        end
      end
    end
  end

  describe "when validating all required parameters are present" do
    it "should be able to validate that all required parameters are present" do
      environment.known_resource_types.add(
        Oregano::Resource::Type.new(:definition, "required_param", :arguments => {"a" => nil})
      )
      expect { Oregano::Resource.new("required_param", "name", :environment => environment).validate_complete }.to raise_error(Oregano::ParseError)
    end

    it "should not fail when all required parameters are present" do
      environment.known_resource_types.add(
        Oregano::Resource::Type.new(:definition, "no_required_param")
      )
      resource = Oregano::Resource.new("no_required_param", "name", :environment => environment)
      resource["a"] = "meh"
      expect { resource.validate_complete }.not_to raise_error
    end

    it "should not validate against builtin types" do
      expect { Oregano::Resource.new("file", "/bar").validate_complete }.not_to raise_error
    end
  end

  describe "when referring to a resource with name canonicalization" do
    it "should canonicalize its own name" do
      res = Oregano::Resource.new("file", "/path/")
      expect(res.uniqueness_key).to eq(["/path"])
      expect(res.ref).to eq("File[/path/]")
    end
  end

  describe "when running in strict mode" do
    it "should be strict" do
      expect(Oregano::Resource.new("file", "/path", :strict => true)).to be_strict
    end

    it "should fail if invalid parameters are used" do
      expect { Oregano::Resource.new("file", "/path", :strict => true, :parameters => {:nosuchparam => "bar"}) }.to raise_error(Oregano::Error, /no parameter named 'nosuchparam'/)
    end

    it "should fail if the resource type cannot be resolved" do
      expect { Oregano::Resource.new("nosuchtype", "/path", :strict => true) }.to raise_error(ArgumentError, /Invalid resource type/)
    end
  end

  describe "when managing parameters" do
    before do
      @resource = Oregano::Resource.new("file", "/my/file")
    end

    it "should correctly detect when provided parameters are not valid for builtin types" do
      expect(Oregano::Resource.new("file", "/my/file")).not_to be_valid_parameter("foobar")
    end

    it "should correctly detect when provided parameters are valid for builtin types" do
      expect(Oregano::Resource.new("file", "/my/file")).to be_valid_parameter("mode")
    end

    it "should correctly detect when provided parameters are not valid for defined resource types" do
      type = Oregano::Resource::Type.new(:definition, "foobar")
      environment.known_resource_types.add type
      expect(Oregano::Resource.new("foobar", "/my/file", :environment => environment)).not_to be_valid_parameter("myparam")
    end

    it "should correctly detect when provided parameters are valid for defined resource types" do
      type = Oregano::Resource::Type.new(:definition, "foobar", :arguments => {"myparam" => nil})
      environment.known_resource_types.add type
      expect(Oregano::Resource.new("foobar", "/my/file", :environment => environment)).to be_valid_parameter("myparam")
    end

    it "should allow setting and retrieving of parameters" do
      @resource[:foo] = "bar"
      expect(@resource[:foo]).to eq("bar")
    end

    it "should allow setting of parameters at initialization" do
      expect(Oregano::Resource.new("file", "/my/file", :parameters => {:foo => "bar"})[:foo]).to eq("bar")
    end

    it "should canonicalize retrieved parameter names to treat symbols and strings equivalently" do
      @resource[:foo] = "bar"
      expect(@resource["foo"]).to eq("bar")
    end

    it "should canonicalize set parameter names to treat symbols and strings equivalently" do
      @resource["foo"] = "bar"
      expect(@resource[:foo]).to eq("bar")
    end

    it "should set the namevar when asked to set the name" do
      resource = Oregano::Resource.new("user", "bob")
      Oregano::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      resource[:name] = "bob"
      expect(resource[:myvar]).to eq("bob")
    end

    it "should return the namevar when asked to return the name" do
      resource = Oregano::Resource.new("user", "bob")
      Oregano::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      resource[:myvar] = "test"
      expect(resource[:name]).to eq("test")
    end

    it "should be able to set the name for non-builtin types" do
      resource = Oregano::Resource.new(:foo, "bar")
      resource[:name] = "eh"
      expect { resource[:name] = "eh" }.to_not raise_error
    end

    it "should be able to return the name for non-builtin types" do
      resource = Oregano::Resource.new(:foo, "bar")
      resource[:name] = "eh"
      expect(resource[:name]).to eq("eh")
    end

    it "should be able to iterate over parameters" do
      @resource[:foo] = "bar"
      @resource[:fee] = "bare"
      params = {}
      @resource.each do |key, value|
        params[key] = value
      end
      expect(params).to eq({:foo => "bar", :fee => "bare"})
    end

    it "should include Enumerable" do
      expect(@resource.class.ancestors).to be_include(Enumerable)
    end

    it "should have a method for testing whether a parameter is included" do
      @resource[:foo] = "bar"
      expect(@resource).to be_has_key(:foo)
      expect(@resource).not_to be_has_key(:eh)
    end

    it "should have a method for providing the list of parameters" do
      @resource[:foo] = "bar"
      @resource[:bar] = "foo"
      keys = @resource.keys
      expect(keys).to be_include(:foo)
      expect(keys).to be_include(:bar)
    end

    it "should have a method for providing the number of parameters" do
      @resource[:foo] = "bar"
      expect(@resource.length).to eq(1)
    end

    it "should have a method for deleting parameters" do
      @resource[:foo] = "bar"
      @resource.delete(:foo)
      expect(@resource[:foo]).to be_nil
    end

    it "should have a method for testing whether the parameter list is empty" do
      expect(@resource).to be_empty
      @resource[:foo] = "bar"
      expect(@resource).not_to be_empty
    end

    it "should be able to produce a hash of all existing parameters" do
      @resource[:foo] = "bar"
      @resource[:fee] = "yay"

      hash = @resource.to_hash
      expect(hash[:foo]).to eq("bar")
      expect(hash[:fee]).to eq("yay")
    end

    it "should not provide direct access to the internal parameters hash when producing a hash" do
      hash = @resource.to_hash
      hash[:foo] = "bar"
      expect(@resource[:foo]).to be_nil
    end

    it "should use the title as the namevar to the hash if no namevar is present" do
      resource = Oregano::Resource.new("user", "bob")
      Oregano::Type.type(:user).stubs(:key_attributes).returns [:myvar]
      expect(resource.to_hash[:myvar]).to eq("bob")
    end

    it "should set :name to the title if :name is not present for non-builtin types" do
      krt = Oregano::Resource::TypeCollection.new("myenv")
      krt.add Oregano::Resource::Type.new(:definition, :foo)
      resource = Oregano::Resource.new :foo, "bar"
      resource.stubs(:known_resource_types).returns krt
      expect(resource.to_hash[:name]).to eq("bar")
    end
  end

  describe "when serializing a native type" do
    before do
      @resource = Oregano::Resource.new("file", "/my/file")
      @resource["one"] = "test"
      @resource["two"] = "other"
    end

    # PUP-3272, needs to work becuse serialization is not only to network
    #
    it "should produce an equivalent yaml object" do
      text = @resource.render('yaml')

      newresource = Oregano::Resource.convert_from('yaml', text)
      expect(newresource).to equal_resource_attributes_of(@resource)
    end

    # PUP-3272, since serialization to network is done in json, not yaml
    it "should produce an equivalent json object" do
      text = @resource.render('json')

      newresource = Oregano::Resource.convert_from('json', text)
      expect(newresource).to equal_resource_attributes_of(@resource)
    end
  end

  describe "when serializing a defined type" do
    before do
      type = Oregano::Resource::Type.new(:definition, "foo::bar")
      environment.known_resource_types.add type

      @resource = Oregano::Resource.new('foo::bar', 'xyzzy', :environment => environment)
      @resource['one'] = 'test'
      @resource['two'] = 'other'
      @resource.resource_type
    end

    it "doesn't include transient instance variables (#4506)" do
      expect(@resource.to_data_hash.keys).to_not include('rstype')
    end

    it "produces an equivalent json object" do
      text = @resource.render('json')

      newresource = Oregano::Resource.convert_from('json', text)
      expect(newresource).to equal_resource_attributes_of(@resource)
    end

    it 'to_data_hash returns value that is instance of to Data' do
      Oregano::Pops::Types::TypeAsserter.assert_instance_of('', Oregano::Pops::Types::TypeFactory.data, @resource.to_data_hash)
      expect(Oregano::Pops::Types::TypeFactory.data.instance?(@resource.to_data_hash)).to be_truthy
    end
  end

  describe "when converting to a RAL resource" do
    it "should use the resource type's :new method to create the resource if the resource is of a builtin type" do
      resource = Oregano::Resource.new("file", basepath+"/my/file")
      result = resource.to_ral
      expect(result).to be_instance_of(Oregano::Type.type(:file))
      expect(result[:path]).to eq(basepath+"/my/file")
    end

    it "should convert to a component instance if the resource type is not of a builtin type" do
      resource = Oregano::Resource.new("foobar", "somename")
      result = resource.to_ral

      expect(result).to be_instance_of(Oregano::Type.type(:component))
      expect(result.title).to eq("Foobar[somename]")
    end
  end

  describe "when converting to oregano code" do
    before do
      @resource = Oregano::Resource.new("one::two", "/my/file",
        :parameters => {
          :noop => true,
          :foo => %w{one two},
          :ensure => 'present',
        }
      )
    end

    it "should escape internal single quotes in a title" do
      singlequote_resource = Oregano::Resource.new("one::two", "/my/file'b'a'r",
        :parameters => {
          :ensure => 'present',
        }
      )
      expect(singlequote_resource.to_manifest).to eq <<-HEREDOC.gsub(/^\s{8}/, '').gsub(/\n$/, '')
        one::two { '/my/file\\'b\\'a\\'r':
          ensure => 'present',
        }
      HEREDOC

    end

    it "should align, sort and add trailing commas to attributes with ensure first" do
      expect(@resource.to_manifest).to eq <<-HEREDOC.gsub(/^\s{8}/, '').gsub(/\n$/, '')
        one::two { '/my/file':
          ensure => 'present',
          foo    => ['one', 'two'],
          noop   => true,
        }
      HEREDOC
    end
  end

  describe "when converting to Yaml for Hiera" do
    before do
      @resource = Oregano::Resource.new("one::two", "/my/file",
        :parameters => {
          :noop => true,
          :foo => %w{one two},
          :ensure => 'present',
        }
      )
    end

    it "should align and sort to attributes with ensure first" do
      expect(@resource.to_hierayaml).to eq <<-HEREDOC.gsub(/^\s{8}/, '')
          /my/file:
            ensure: 'present'
            foo   : ['one', 'two']
            noop  : true
      HEREDOC
    end
  end
  describe "when converting to json" do
    # LAK:NOTE For all of these tests, we convert back to the resource so we can
    # trap the actual data structure then.

    it "should set its type to the provided type" do
      expect(Oregano::Resource.from_data_hash(JSON.parse(Oregano::Resource.new("File", "/foo").to_json)).type).to eq("File")
    end

    it "should set its title to the provided title" do
      expect(Oregano::Resource.from_data_hash(JSON.parse(Oregano::Resource.new("File", "/foo").to_json)).title).to eq("/foo")
    end

    it "should include all tags from the resource" do
      resource = Oregano::Resource.new("File", "/foo")
      resource.tag("yay")

      expect(Oregano::Resource.from_data_hash(JSON.parse(resource.to_json)).tags).to eq(resource.tags)
    end

    it "should include the file if one is set" do
      resource = Oregano::Resource.new("File", "/foo")
      resource.file = "/my/file"

      expect(Oregano::Resource.from_data_hash(JSON.parse(resource.to_json)).file).to eq("/my/file")
    end

    it "should include the line if one is set" do
      resource = Oregano::Resource.new("File", "/foo")
      resource.line = 50

      expect(Oregano::Resource.from_data_hash(JSON.parse(resource.to_json)).line).to eq(50)
    end

    it "should include the 'exported' value if one is set" do
      resource = Oregano::Resource.new("File", "/foo")
      resource.exported = true

      expect(Oregano::Resource.from_data_hash(JSON.parse(resource.to_json)).exported?).to be_truthy
    end

    it "should set 'exported' to false if no value is set" do
      resource = Oregano::Resource.new("File", "/foo")

      expect(Oregano::Resource.from_data_hash(JSON.parse(resource.to_json)).exported?).to be_falsey
    end

    it "should set all of its parameters as the 'parameters' entry" do
      resource = Oregano::Resource.new("File", "/foo")
      resource[:foo] = %w{bar eh}
      resource[:fee] = %w{baz}

      result = Oregano::Resource.from_data_hash(JSON.parse(resource.to_json))
      expect(result["foo"]).to eq(%w{bar eh})
      expect(result["fee"]).to eq(%w{baz})
    end

    it "should set sensitive parameters as an array of strings" do
      resource = Oregano::Resource.new("File", "/foo", :sensitive_parameters => [:foo, :fee])
      result = JSON.parse(resource.to_json)
      expect(result["sensitive_parameters"]).to eq ["foo", "fee"]
    end

    it "should serialize relationships as reference strings" do
      resource = Oregano::Resource.new("File", "/foo")
      resource[:requires] = Oregano::Resource.new("File", "/bar")
      result = Oregano::Resource.from_data_hash(JSON.parse(resource.to_json))
      expect(result[:requires]).to eq("File[/bar]")
    end

    it "should serialize multiple relationships as arrays of reference strings" do
      resource = Oregano::Resource.new("File", "/foo")
      resource[:requires] = [Oregano::Resource.new("File", "/bar"), Oregano::Resource.new("File", "/baz")]
      result = Oregano::Resource.from_data_hash(JSON.parse(resource.to_json))
      expect(result[:requires]).to eq([ "File[/bar]",  "File[/baz]" ])
    end
  end

  describe "when converting from json" do
    before do
      @data = {
        'type' => "file",
        'title' => basepath+"/yay",
      }
    end

    it "should set its type to the provided type" do
      expect(Oregano::Resource.from_data_hash(@data).type).to eq("File")
    end

    it "should set its title to the provided title" do
      expect(Oregano::Resource.from_data_hash(@data).title).to eq(basepath+"/yay")
    end

    it "should tag the resource with any provided tags" do
      @data['tags'] = %w{foo bar}
      resource = Oregano::Resource.from_data_hash(@data)
      expect(resource.tags).to be_include("foo")
      expect(resource.tags).to be_include("bar")
    end

    it "should set its file to the provided file" do
      @data['file'] = "/foo/bar"
      expect(Oregano::Resource.from_data_hash(@data).file).to eq("/foo/bar")
    end

    it "should set its line to the provided line" do
      @data['line'] = 50
      expect(Oregano::Resource.from_data_hash(@data).line).to eq(50)
    end

    it "should 'exported' to true if set in the json data" do
      @data['exported'] = true
      expect(Oregano::Resource.from_data_hash(@data).exported).to be_truthy
    end

    it "should 'exported' to false if not set in the json data" do
      expect(Oregano::Resource.from_data_hash(@data).exported).to be_falsey
    end

    it "should fail if no title is provided" do
      @data.delete('title')
      expect { Oregano::Resource.from_data_hash(@data) }.to raise_error(ArgumentError)
    end

    it "should fail if no type is provided" do
      @data.delete('type')
      expect { Oregano::Resource.from_data_hash(@data) }.to raise_error(ArgumentError)
    end

    it "should set each of the provided parameters" do
      @data['parameters'] = {'foo' => %w{one two}, 'fee' => %w{three four}}
      resource = Oregano::Resource.from_data_hash(@data)
      expect(resource['foo']).to eq(%w{one two})
      expect(resource['fee']).to eq(%w{three four})
    end

    it "should convert single-value array parameters to normal values" do
      @data['parameters'] = {'foo' => %w{one}}
      resource = Oregano::Resource.from_data_hash(@data)
      expect(resource['foo']).to eq(%w{one})
    end

    it "converts deserialized sensitive parameters as symbols" do
      @data['sensitive_parameters'] = ['content', 'mode']
      expect(Oregano::Resource.from_data_hash(@data).sensitive_parameters).to eq [:content, :mode]
    end
  end

  it "implements copy_as_resource" do
    resource = Oregano::Resource.new("file", "/my/file")
    expect(resource.copy_as_resource).to eq(resource)
  end

  describe "when copying resources" do
    it "deep copies over 'sensitive' values" do
      rhs = Oregano::Resource.new("file", "/my/file", {:parameters => {:content => "foo"}, :sensitive_parameters => [:content]})
      lhs = Oregano::Resource.new(rhs)
      expect(lhs.sensitive_parameters).to eq [:content]
    end
  end

  describe "because it is an indirector model" do
    it "should include Oregano::Indirector" do
      expect(Oregano::Resource).to be_is_a(Oregano::Indirector)
    end

    it "should have a default terminus" do
      expect(Oregano::Resource.indirection.terminus_class).to be
    end

    it "should have a name" do
      expect(Oregano::Resource.new("file", "/my/file").name).to eq("File//my/file")
    end
  end

  describe "when resolving resources with a catalog" do
    it "should resolve all resources using the catalog" do
      catalog = mock 'catalog'
      resource = Oregano::Resource.new("foo::bar", "yay")
      resource.catalog = catalog

      catalog.expects(:resource).with("Foo::Bar[yay]").returns(:myresource)

      expect(resource.resolve).to eq(:myresource)
    end
  end

  describe "when generating the uniqueness key" do
    it "should include all of the key_attributes in alphabetical order by attribute name" do
      Oregano::Type.type(:file).stubs(:key_attributes).returns [:myvar, :owner, :path]
      Oregano::Type.type(:file).stubs(:title_patterns).returns(
        [ [ /(.*)/, [ [:path, lambda{|x| x} ] ] ] ]
      )
      res = Oregano::Resource.new("file", "/my/file", :parameters => {:owner => 'root', :content => 'hello'})
      expect(res.uniqueness_key).to eq([ nil, 'root', '/my/file'])
    end
  end

  describe '#parse_title' do
    describe 'with a composite namevar' do
      before do
        Oregano::Type.newtype(:composite) do

          newparam(:name)
          newparam(:value)

          # Configure two title patterns to match a title that is either
          # separated with a colon or exclamation point. The first capture
          # will be used for the :name param, and the second capture will be
          # used for the :value param.
          def self.title_patterns
            identity = lambda {|x| x }
            reverse  = lambda {|x| x.reverse }
            [
              [
                /^(.*?):(.*?)$/,
                [
                  [:name, identity],
                  [:value, identity],
                ]
              ],
              [
                /^(.*?)!(.*?)$/,
                [
                  [:name, reverse],
                  [:value, reverse],
                ]
              ],
            ]
          end
        end
      end

      describe "with no matching title patterns" do
        subject { Oregano::Resource.new(:composite, 'unmatching title')}

        it "should raise an exception if no title patterns match" do
          expect do
            subject.to_hash
          end.to raise_error(Oregano::Error, /No set of title patterns matched/)
        end
      end

      describe "with a matching title pattern" do
        subject { Oregano::Resource.new(:composite, 'matching:title') }

        it "should not raise an exception if there was a match" do
          expect do
            subject.to_hash
          end.to_not raise_error
        end

        it "should set the resource parameters from the parsed title values" do
          h = subject.to_hash
          expect(h[:name]).to eq('matching')
          expect(h[:value]).to eq('title')
        end
      end

      describe "and multiple title patterns" do
        subject { Oregano::Resource.new(:composite, 'matching!title') }

        it "should use the first title pattern that matches" do
          h = subject.to_hash
          expect(h[:name]).to eq('gnihctam')
          expect(h[:value]).to eq('eltit')
        end
      end
    end
  end

  describe "#prune_parameters" do
    before do
      Oregano::Type.newtype('blond') do
        newproperty(:ensure)
        newproperty(:height)
        newproperty(:weight)
        newproperty(:sign)
        newproperty(:friends)
        newparam(:admits_to_dying_hair)
        newparam(:admits_to_age)
        newparam(:name)
      end
    end

    it "should strip all parameters and strip properties that are nil, empty or absent except for ensure" do
      resource = Oregano::Resource.new("blond", "Bambi", :parameters => {
        :ensure               => 'absent',
        :height               => '',
        :weight               => 'absent',
        :friends              => [],
        :admits_to_age        => true,
        :admits_to_dying_hair => false
      })

      pruned_resource = resource.prune_parameters
      expect(pruned_resource).to eq(Oregano::Resource.new("blond", "Bambi", :parameters => {:ensure => 'absent'}))
    end

    it "should leave parameters alone if in parameters_to_include" do
      resource = Oregano::Resource.new("blond", "Bambi", :parameters => {
        :admits_to_age        => true,
        :admits_to_dying_hair => false
      })

      pruned_resource = resource.prune_parameters(:parameters_to_include => [:admits_to_dying_hair])
      expect(pruned_resource).to eq(Oregano::Resource.new("blond", "Bambi", :parameters => {:admits_to_dying_hair => false}))
    end

    it "should leave properties if not nil, absent or empty" do
      resource = Oregano::Resource.new("blond", "Bambi", :parameters => {
        :ensure          => 'silly',
        :height          => '7 ft 5 in',
        :friends         => ['Oprah'],
      })

      pruned_resource = resource.prune_parameters
      expect(pruned_resource).to eq(
      resource = Oregano::Resource.new("blond", "Bambi", :parameters => {
        :ensure          => 'silly',
        :height          => '7 ft 5 in',
        :friends         => ['Oprah'],
      })
      )
    end
  end
end
