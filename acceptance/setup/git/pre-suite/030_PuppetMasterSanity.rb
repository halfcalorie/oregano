test_name "Oregano Master sanity checks: PID file and SSL dir creation"

hostname = on(master, 'facter hostname').stdout.strip
fqdn = on(master, 'facter fqdn').stdout.strip

with_oregano_running_on(master, :main => { :dns_alt_names => "oregano,#{hostname},#{fqdn}", :verbose => true, :noop => true }) do
  # SSL dir created?
  step "SSL dir created?"
  on master,  "[ -d #{master.oregano('master')['ssldir']} ]"

  # PID file exists?
  step "PID file created?"
  on master, "[ -f #{master.oregano('master')['pidfile']} ]"
end

step "Create module directories normally handled via packaging"
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"
