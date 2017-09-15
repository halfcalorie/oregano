Development Utilities
=====================

The scripts in this directory are utility scripts useful during development.

binary_search_specs.rb
----------------------

This script, written by Nick Lewis, is useful if you encounter a spec failure which only occurs when run in some sequence with other specs.  If you have a spec which passes by itself, but fails when run with the full spec suite, this script will help track it down.

The oregano spec/spec_helper.rb checks for an environment variable LOG_SPEC_ORDER.  If this is present, it will save the current order of the spec files to './spec_order.txt'.

This file is then used by binary_search_specs.rb so that:

    $ ./util/binary_search_specs.rb spec/unit/foo_spec.rb

will begin bisecting runs before and after this spec until it narrows down to a candidate which seems to be effecting foo_spec.rb and causing it to fail.

### with parallel-spec

To get the groups that the parallel task is running, run: be util/rspec_grouper 1000. Then run each spit out file with "be util/rspec_runner <groupfile>". If it fails, rename it to spec_order.txt and run the binary script.

dev-oregano-master
-----------------

This script is very helpful for setting up a local oregano master daemon which you can then interrogate with other oregano 'app' calls such as oregano cert or oregano agent.  I'm not sure who wrote it originally.

There are a few steps needed to get this configured properly.

* /etc/hosts needs a 'oreganomaster' added to its localhost entry

The dev-oregano-master script calls `oregano master` with --certname=oreganomaster, and this needs to resolve locally.

You can execute the dev-oregano-master script with a name for the sandbox configuration directory (which will be placed in ~/test/master) or it will use 'default'.

* ./util/dev-oregano-master bar-env

(places conf and var info in ~/tests/master/bar-env for instance)

You should now be able to do things like:

    jpartlow@percival:~/work/oregano$ bundler exec oregano agent -t --server oreganomaster
    Info: Creating a new SSL key for percival.corp.oreganolabs.net
    Info: Caching certificate for ca
    Info: Creating a new SSL certificate request for percival.corp.oreganolabs.net
    Info: Certificate Request fingerprint (SHA256): 1B:DE:91:8C:AE:10:1B:18:0D:67:9D:4B:87:F1:26:19:6D:C6:37:35:F6:64:40:90:CF:FC:BE:8F:6F:C9:8D:D4
    Info: Caching certificate for percival.corp.oreganolabs.net
    Info: Caching certificate_revocation_list for ca
    Info: Retrieving plugin
    Info: Caching catalog for percival.corp.oreganolabs.net
    Info: Applying configuration version '1374193823'
    Info: Creating state file /home/jpartlow/.oregano/var/state/state.yaml
    Notice: Finished catalog run in 0.04 seconds

For an agent run (or any command you want to call the server), you must specify '--server oreganomaster'.

To check the oreganomaster's certs, you instead would need to specify the confdir/vardir:

    jpartlow@percival:~/work/oregano$ bundler exec oregano cert list --all --confdir=~/test/master/default --vardir= ~/test/master/default/
    + "percival.corp.oreganolabs.net" (SHA256) 0D:8D:A4:F1:19:E3:7A:62:ED:ED:21:B4:76:FE:04:47:50:01:20:4A:04:48:09:3A:1A:98:86:4A:08:8D:46:F0
    + "oreganomaster"                 (SHA256) B9:F5:06:F4:74:3B:15:CE:7C:7B:A6:38:83:0E:30:6A:6F:DC:F4:FD:FF:B1:A9:8A:35:12:90:10:26:46:C2:A6 (alt names: "DNS:percival.corp.oreganolabs.net", "DNS:oregano", "DNS:oregano.corp.oreganolabs.net", "DNS:oreganomaster")

### Curl

For simple cases of testing REST API via curl:

* edit ~/tests/master/:confdir/auth.conf and add `"allow *"` to `"path /"`

Now you should be able to:

```bash
jpartlow@percival:~/work/oregano$ curl -k -H 'Accept: text/pson' https://oreganomaster:8140/main/resource/user/nobody
{"type":"User","title":"nobody","tags":["user","nobody"],"exported":false,"parameters":{"ensure":"present","home":"/nonexistent","uid":65534,"gid":65534,"comment":"nobody","shell":"/bin/sh","groups":[],"expiry":"absent","provider":"useradd","membership":"minimum","role_membership":"minimum","auth_membership":"minimum","profile_membership":"minimum","key_membership":"minimum","attribute_membership":"minimum","loglevel":"notice"}}
```

For more complex authorization cases you will need to reference the agents keys:

```bash
jpartlow@percival:~/work/oregano$ curl -H 'Accept: text/pson' --cert `oregano agent --configprint hostcert` --key `be oregano agent --configprint hostprivkey` --cacert `be oregano agent --configprint localcacert` https://oreganomaster:8140/foo/node/percival.corp.oreganolabs.net
```
