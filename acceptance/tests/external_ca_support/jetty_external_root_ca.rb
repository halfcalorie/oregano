begin
  require 'oregano_x/acceptance/external_cert_fixtures'
rescue LoadError
  $LOAD_PATH.unshift(File.expand_path('../../../lib', __FILE__))
  require 'oregano_x/acceptance/external_cert_fixtures'
end

confine :except, :type => 'pe'

skip_test "Test only supported on Jetty" unless @options[:is_oreganoserver]

# Verify that a trivial manifest can be run to completion.
# Supported Setup: Single, Root CA
#  - Agent and Master SSL cert issued by the Root CA
#  - Revocation disabled on the agent `certificate_revocation = false`
#  - CA disabled on the master `ca = false`
#
test_name "Oregano agent and master work when both configured with externally issued certificates from independent intermediate CAs"

tag 'audit:medium',
    'audit:integration',  # This could also be a component in a platform workflow test.
    'server'

step "Copy certificates and configuration files to the master..."
fixture_dir = File.expand_path('../fixtures', __FILE__)
testdir = master.tmpdir('jetty_external_root_ca')
backupdir = master.tmpdir('jetty_external_root_ca_backup')
fixtures = OreganoX::Acceptance::ExternalCertFixtures.new(fixture_dir, testdir)

jetty_confdir = master['oreganoserver-confdir']

# Register our cleanup steps early in a teardown so that they will happen even
# if execution aborts part way.
teardown do
  step "Restore /etc/hosts and oreganoserver configs; Restart oreganoserver"
  on master, "cp -p '#{backupdir}/hosts' /etc/hosts"
  # Please note that the escaped `\cp` command below is intentional. Most
  # linux systems alias `cp` to `cp -i` which causes interactive mode to be
  # invoked when copying directories that do not yet exist at the target
  # location, even when using the force flag. The escape ensures that an
  # alias is not used.
  on master, "\\cp -frp #{backupdir}/oreganoserver/* #{jetty_confdir}/../"
  on(master, "service #{master['oreganoservice']} restart")
end

# Backup files in scope for modification by test
on master, "cp -p /etc/hosts '#{backupdir}/hosts'"
on master, "cp -rp '#{jetty_confdir}/..' '#{backupdir}/oreganoserver'"


# Read all of the CA certificates.

# Copy all of the x.509 fixture data over to the master.
create_remote_file master, "#{testdir}/ca_root.crt", fixtures.root_ca_cert
create_remote_file master, "#{testdir}/ca_agent.crt", fixtures.agent_ca_cert
create_remote_file master, "#{testdir}/ca_master.crt", fixtures.master_ca_cert
create_remote_file master, "#{testdir}/ca_master.crl", fixtures.master_ca_crl
create_remote_file master, "#{testdir}/ca_master_bundle.crt", "#{fixtures.master_ca_cert}\n#{fixtures.root_ca_cert}\n"
create_remote_file master, "#{testdir}/ca_agent_bundle.crt", "#{fixtures.agent_ca_cert}\n#{fixtures.root_ca_cert}\n"
create_remote_file master, "#{testdir}/agent.crt", fixtures.agent_cert
create_remote_file master, "#{testdir}/agent.key", fixtures.agent_key
create_remote_file master, "#{testdir}/agent_email.crt", fixtures.agent_email_cert
create_remote_file master, "#{testdir}/agent_email.key", fixtures.agent_email_key
create_remote_file master, "#{testdir}/master.crt", fixtures.master_cert
create_remote_file master, "#{testdir}/master.key", fixtures.master_key
create_remote_file master, "#{testdir}/master_rogue.crt", fixtures.master_cert_rogue
create_remote_file master, "#{testdir}/master_rogue.key", fixtures.master_key_rogue

##
# Now create the master and agent oregano.conf
#
on master, "mkdir -p #{testdir}/etc/agent"

# Make master1.example.org resolve if it doesn't already.
on master, "grep -q -x '#{fixtures.host_entry}' /etc/hosts || echo '#{fixtures.host_entry}' >> /etc/hosts"

create_remote_file master, "#{testdir}/etc/agent/oregano.conf", fixtures.agent_conf
create_remote_file master, "#{testdir}/etc/agent/oregano.conf.crl", fixtures.agent_conf_crl
create_remote_file master, "#{testdir}/etc/agent/oregano.conf.email", fixtures.agent_conf_email

# auth.conf to allow *.example.com access to the rest API
create_remote_file master, "#{jetty_confdir}/auth.conf", fixtures.auth_conf
# set use-legacy-auth-conf = false
# to override the default setting in older oreganoserver versions
modify_tk_config(master, options['oreganoserver-config'], {'jruby-oregano' => {'use-legacy-auth-conf' => false}})

step "Set filesystem permissions and ownership for the master"
# These permissions are required for the JVM to start Oregano as oregano
on master, "chown -R oregano:oregano #{testdir}/*.{crt,key,crl}"

# These permissions are just for testing, end users should protect their
# private keys.
on master, "chmod -R a+rX #{testdir}"

agent_cmd_prefix = "--confdir #{testdir}/etc/agent --vardir #{testdir}/etc/agent/var"

# Move the agent SSL cert and key into place.
# The filename must match the configured certname, otherwise Oregano will try
# and generate a new certificate and key
step "Configure the agent with the externally issued certificates"
on master, "mkdir -p #{testdir}/etc/agent/ssl/{public_keys,certs,certificate_requests,private_keys,private}"
create_remote_file master, "#{testdir}/etc/agent/ssl/certs/#{fixtures.agent_name}.pem", fixtures.agent_cert
create_remote_file master, "#{testdir}/etc/agent/ssl/private_keys/#{fixtures.agent_name}.pem", fixtures.agent_key

create_remote_file master, "#{jetty_confdir}/webserver.conf",
                   fixtures.jetty_webserver_conf_for_trustworthy_master

master_opts = {
    'master' => {
        'certname' => fixtures.master_name,
        'ssl_client_header' => "HTTP_X_CLIENT_DN",
        'ssl_client_verify_header' => "HTTP_X_CLIENT_VERIFY"
    }
}

# disable CA service
# https://github.com/oreganolabs/oreganoserver/blob/master/documentation/configuration.markdown#service-bootstrapping
create_remote_file master, "#{jetty_confdir}/../services.d/ca.cfg", "oreganolabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service"
on(master, "service #{master['oreganoservice']} restart")

step "Start the Oregano master service..."
with_oregano_running_on(master, master_opts) do
  # Now, try and run the agent on the master against itself.
  step "Successfully run the oregano agent on the master"
  on master, oregano_agent("#{agent_cmd_prefix} --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /Creating a new SSL key/, stdout
    assert_no_match /\Wfailed\W/i, stderr
    assert_no_match /\Wfailed\W/i, stdout
    assert_no_match /\Werror\W/i, stderr
    assert_no_match /\Werror\W/i, stdout
    # Assert the exit code so we get a "Failed test" instead of an "Errored test"
    assert exit_code == 0
  end

  step "Master accepts client cert with email address in subject"
  on master, "cp #{testdir}/etc/agent/oregano.conf{,.no_email}"
  on master, "cp #{testdir}/etc/agent/oregano.conf{.email,}"
  on master, oregano_agent("#{agent_cmd_prefix} --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /\Wfailed\W/i, stdout
    assert_no_match /\Wfailed\W/i, stderr
    assert_no_match /\Werror\W/i, stdout
    assert_no_match /\Werror\W/i, stderr
    # Assert the exit code so we get a "Failed test" instead of an "Errored test"
    assert exit_code == 0
  end

  step "Agent refuses to connect to revoked master"
  on master, "cp #{testdir}/etc/agent/oregano.conf{,.no_crl}"
  on master, "cp #{testdir}/etc/agent/oregano.conf{.crl,}"

  revoke_opts = "--hostcrl #{testdir}/ca_master.crl"
  on master, oregano_agent("#{agent_cmd_prefix} #{revoke_opts} --test"), :acceptable_exit_codes => (0..255) do
    assert_match /certificate revoked.*?example.org/, stderr
    assert exit_code == 1
  end
end

create_remote_file master, "#{jetty_confdir}/webserver.conf",
                   fixtures.jetty_webserver_conf_for_rogue_master

with_oregano_running_on(master, master_opts) do
  step "Agent refuses to connect to a rogue master"
  on master, oregano_agent("#{agent_cmd_prefix} --ssl_client_ca_auth=#{testdir}/ca_master.crt --test"), :acceptable_exit_codes => (0..255) do
    assert_no_match /Creating a new SSL key/, stdout
    assert_match /certificate verify failed/i, stderr
    assert_match /The server presented a SSL certificate chain which does not include a CA listed in the ssl_client_ca_auth file/i, stderr
    assert exit_code == 1
  end
end

step "Finished testing External Certificates"
