require 'oregano/acceptance/install_utils'

extend Oregano::Acceptance::InstallUtils

test_name "Stop firewall" do
  hosts.each do |host|
    stop_firewall_on(host)
  end
end
