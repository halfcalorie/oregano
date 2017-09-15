test_name 'Oregano User and Group' do
  hosts.each do |host|

    step "ensure oregano user and group added to all nodes because this is what the packages do" do
      on host, oregano("resource user oregano ensure=present")
      on host, oregano("resource group oregano ensure=present")
    end

  end
end
