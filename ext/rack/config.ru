# a config.ru, for use with every rack-compatible webserver.
# SSL needs to be handled outside this, though.

# if oregano is not in your RUBYLIB:
# $LOAD_PATH.unshift('/opt/oregano/lib')

$0 = "master"

# if you want debugging:
# ARGV << "--debug"

ARGV << "--rack"

# Rack applications typically don't start as root.  Set --confdir, --vardir,
# --logdir, --rundir to prevent reading configuration from
# ~/ based pathing.
ARGV << "--confdir" << "/etc/oreganolabs/oregano"
ARGV << "--vardir"  << "/opt/oreganolabs/server/data/oreganomaster"
ARGV << "--logdir"  << "/var/log/oreganolabs/oreganomaster"
ARGV << "--rundir"  << "/var/run/oreganolabs/oreganomaster"
ARGV << "--codedir"  << "/etc/oreganolabs/code"

# disable always_retry_plugsin as a performance improvement. This is safe for a master to
# apply. This is intended to allow agents to recognize new features that may be
# delivered during catalog compilation.
ARGV << "--no-always_retry_plugins"

# NOTE: it's unfortunate that we have to use the "CommandLine" class
#  here to launch the app, but it contains some initialization logic
#  (such as triggering the parsing of the config file) that is very
#  important.  We should do something less nasty here when we've
#  gotten our API and settings initialization logic cleaned up.
#
# Also note that the "$0 = master" line up near the top here is
#  the magic that allows the CommandLine class to know that it's
#  supposed to be running master.
#
# --cprice 2012-05-22

require 'oregano/util/command_line'
# we're usually running inside a Rack::Builder.new {} block,
# therefore we need to call run *here*.
run Oregano::Util::CommandLine.new.execute

