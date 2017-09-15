test_name 'Update pe-oregano pkg' do

  repo_path = ENV['PUPPET_REPO_CONFIGS']
  version = ENV['PUPPET_REF']

  unless repo_path && version
    skip_test "The oregano version to install isn't specified, using what's in the tarball..."
  end

  hosts.each do |host|
    deploy_package_repo(host, repo_path, "pe-oregano", version)
    host.upgrade_package("pe-oregano")
  end

  with_oregano_running_on master, {} do
    # this bounces the oregano master for us
  end
end
