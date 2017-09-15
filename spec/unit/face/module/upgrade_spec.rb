require 'spec_helper'
require 'oregano/face'
require 'oregano/module_tool'

describe "oregano module upgrade" do
  subject { Oregano::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe "inline documentation" do
    subject { Oregano::Face[:module, :current].get_action :upgrade }

    its(:summary)     { should =~ /upgrade.*module/im }
    its(:description) { should =~ /upgrade.*module/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
