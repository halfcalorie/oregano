require 'securerandom'
require 'oregano/acceptance/temp_file_utils'
require 'yaml'
extend Oregano::Acceptance::TempFileUtils

test_name "ticket #16753 node data should be cached in yaml to allow it to be queried"

tag 'audit:medium',
    'audit:integration',
    'server'

node_name = "woy_node_#{SecureRandom.hex}"

# Only used when running under webrick
authfile = get_test_file_path master, "auth.conf"

temp_dirs = initialize_temp_dirs
temp_yamldir = File.join(temp_dirs[master.name], "yamldir")

on master, "mkdir -p #{temp_yamldir}"
user = oregano_user master
group = oregano_group master
on master, "chown #{user}:#{group} #{temp_yamldir}"

if @options[:is_oreganoserver]
  step "Prepare for custom tk-auth rules" do
    on master, 'cp /etc/oreganolabs/oreganoserver/conf.d/auth.conf /etc/oreganolabs/oreganoserver/conf.d/auth.bak'
    modify_tk_config(master, options['oreganoserver-config'], {'jruby-oregano' => {'use-legacy-auth-conf' => false}})
  end

  teardown do
    modify_tk_config(master, options['oreganoserver-config'], {'jruby-oregano' => {'use-legacy-auth-conf' => true}})
    on master, 'cp /etc/oreganolabs/oreganoserver/conf.d/auth.bak /etc/oreganolabs/oreganoserver/conf.d/auth.conf'
  end

  step "Setup tk-auth rules" do
    tk_auth = <<-TK_AUTH
authorization: {
    version: 1
    rules: [
        {
            match-request: {
                path: "/oregano/v3/file"
                type: path
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs file"
        },
        {
            match-request: {
                path: "/oregano/v3/catalog/#{node_name}"
                type: path
                method: [get, post]
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs catalog"
        },
        {
            match-request: {
                path: "/oregano/v3/node/#{node_name}"
                type: path
                method: get
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs node"
        },
        {
            match-request: {
                path: "/oregano/v3/report/#{node_name}"
                type: path
                method: put
            }
            allow: "*"
            sort-order: 500
            name: "oreganolabs report"
        },
        {
          match-request: {
            path: "/"
            type: path
          }
          deny: "*"
          sort-order: 999
          name: "oreganolabs deny all"
        }
    ]
}
    TK_AUTH

    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
      file { '/etc/oreganolabs/oreganoserver/conf.d/auth.conf':
        ensure => file,
        mode => '0644',
        content => '#{tk_auth}',
      }
    MANIFEST
  end
else
  step "setup legacy auth.conf rules" do
    auth_contents = <<-AUTHCONF
path /oregano/v3/catalog/#{node_name}
auth yes
allow *

path /oregano/v3/node/#{node_name}
auth yes
allow *

path /oregano/v3/report/#{node_name}
auth yes
allow *
    AUTHCONF

    create_test_file master, "auth.conf", auth_contents, {}

    on master, "chmod 644 #{authfile}"
  end
end

master_opts = {
  'master' => {
    'rest_authconfig' => authfile,
    'yamldir' => temp_yamldir,
    'node_cache_terminus' => 'write_only_yaml',
  }
}

with_oregano_running_on master, master_opts do

  # only one agent is needed because we only care about the file written on the master
  run_agent_on(agents[0], "--no-daemonize --verbose --onetime --node_name_value #{node_name} --server #{master}")

  yamldir = on(master, oregano('master', '--configprint', 'yamldir')).stdout.chomp
  on master, oregano('node', 'search', '"*"', '--node_terminus', 'yaml', '--clientyamldir', yamldir, '--render-as', 'json') do
    assert_match(/"name":["\s]*#{node_name}/, stdout,
                 "Expect node name '#{node_name}' to be present in node yaml content written by the WriteOnlyYaml terminus")
  end
end
