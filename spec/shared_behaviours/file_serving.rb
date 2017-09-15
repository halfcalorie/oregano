#! /usr/bin/env ruby

shared_examples_for "Oregano::FileServing::Files" do |indirection|
  %w[find search].each do |method|
    let(:request) { Oregano::Indirector::Request.new(indirection, method, 'foo', nil) }

    describe "##{method}" do
      it "should proxy to file terminus if the path is absolute" do
        request.key = make_absolute('/tmp/foo')

        described_class.indirection.terminus(:file).class.any_instance.expects(method).with(request)

        subject.send(method, request)
      end

      it "should proxy to file terminus if the protocol is file" do
        request.protocol = 'file'

        described_class.indirection.terminus(:file).class.any_instance.expects(method).with(request)

        subject.send(method, request)
      end

      describe "when the protocol is oregano" do
        before :each do
          request.protocol = 'oregano'
        end

        describe "and a server is specified" do
          before :each do
            request.server = 'oregano_server'
          end

          it "should proxy to rest terminus if default_file_terminus is rest" do
            Oregano[:default_file_terminus] = "rest"

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end

          it "should proxy to rest terminus if default_file_terminus is not rest" do
            Oregano[:default_file_terminus] = 'file_server'

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end
        end

        describe "and no server is specified" do
          before :each do
            request.server = nil
          end

          it "should proxy to file_server if default_file_terminus is 'file_server'" do
            Oregano[:default_file_terminus] = 'file_server'

            described_class.indirection.terminus(:file_server).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end

          it "should proxy to rest if default_file_terminus is 'rest'" do
            Oregano[:default_file_terminus] = "rest"

            described_class.indirection.terminus(:rest).class.any_instance.expects(method).with(request)

            subject.send(method, request)
          end
        end
      end
    end
  end
end
