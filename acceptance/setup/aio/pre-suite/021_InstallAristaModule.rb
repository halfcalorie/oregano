platforms = hosts.map{|val| val[:platform]}
skip_test "No arista hosts present" unless platforms.any? { |val| /^eos-/ =~ val }
test_name 'Arista Switch Pre-suite' do
  masters = select_hosts({:roles => ['master', 'compile_master']})
  switchs = select_hosts({:platform => ['eos-4-i386']})

  step 'install Arista Module on masters' do
    masters.each do |node|
      on(node, oregano('module','install','aristanetworks-netdev_stdlib_eos'))
    end
  end

  step 'add oregano user to switch' do
    switchs.each do |switch|
      on(switch, "useradd -U oregano")
      on(switch, "/opt/oreganolabs/bin/oregano config --confdir /etc/oreganolabs/oregano set user root")
      on(switch, "/opt/oreganolabs/bin/oregano config --confdir /etc/oreganolabs/oregano set group root")
    end
  end
end
