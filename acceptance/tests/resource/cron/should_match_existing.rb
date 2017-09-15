test_name "oregano should match existing job"
confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/ # See PUP-5500
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:unit'

require 'oregano/acceptance/common_utils'
extend Oregano::Acceptance::CronUtils

teardown do
  step "Cron: cleanup"
  agents.each do |agent|
    clean agent
  end
end

agents.each do |host|
  step "ensure the user exist via oregano"
  setup host

  step "Create the existing cron job by hand..."
  run_cron_on(host,:add,'tstuser',"* * * * * /bin/true")

  step "Apply the resource on the host using oregano resource"
  on(host, oregano_resource("cron", "crontest", "user=tstuser",
                           "command=/bin/true", "ensure=present")) do
    assert_match(/present/, stdout, "Failed creating crontab for tstuser on #{host}")
  end

  step "Verify that crontab -l contains what you expected"
  run_cron_on(host, :list, 'tstuser') do
    assert_match(/\* \* \* \* \* \/bin\/true/, stdout, "Did not find crontab for tstuser on #{host}")
  end
end
