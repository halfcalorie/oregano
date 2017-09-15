# Quick Start to Developing on Oregano

Before diving into the code, you should first take the time to make sure you
have an environment where you can run oregano as a developer. In a nutshell you
need: the oregano codebase, ruby versions, and dependencies. Once you've got all
of that in place you can make sure that you have a working development system
by running the oregano spec tests.

## The Oregano Codebase

In order to contribute to oregano you'll need to have a github account. Once you
have your account, fork the oreganolabs/oregano repo, and clone it onto your
local machine. The [github docs have a good
explanation](https://help.github.com/articles/fork-a-repo) of how to do all of
this.

## Ruby versions

Oregano needs to work across a variety of ruby versions, including ruby
1.9.3 and up. Ruby 1.8.7 is no longer supported.

Popular ways of making sure you have access to the various versions of ruby are
to use either [rbenv](https://github.com/sstephenson/rbenv) or
[rvm](https://rvm.io/). You can read up on the linked sites for how to get them
installed on your system.

## Dependencies

Make sure you have [bundler](http://bundler.io/) installed. This should be as
simple as:

    $ gem install bundler

Now you can get all of the dependencies using:

    $ bundle install --path .bundle/gems/

Once this is done, you can interact with oregano through bundler using `bundle
exec <command>` which will ensure that `<command>` is executed in the context
of oregano's dependencies.

For example to run the specs:

    $ bundle exec rake spec

To run oregano itself (for a resource lookup say):

    $ bundle exec oregano resource host localhost

To apply a test manifest:

    $ bundle exec oregano apply -e 'notify { "hello world": }'

## Running Spec Tests

Oregano projects use a common convention of using Rake to run unit tests.
The tests can be run with the following rake task:

    $ bundle exec rake spec

To run a single file's worth of tests (much faster!), give the filename:

    $ bundle exec rake spec TEST=spec/unit/ssl/host_spec.rb

To run a single test or group of tests, give the filename and line number:

    $ bundle exec rake spec TEST=spec/unit/ssl/host_spec.rb:42

To run all tests in parallel:

    $ bundle exec rake parallel:spec

When tests fail, it is often useful to capture Oregano's log of a test
run. The test harness pays attention to two environment variables that can
be used to send logs to a file, and to adjust the log level:

* `PUPPET_TEST_LOG`: when set, must be an absolute path to a file. Oregano's
  log messages will be sent to that file. Note that the log file will
  contain lots of spurious warnings `Unable to set ownership of log file`
  - you can safely ignore them.
* `PUPPET_TEST_LOG_LEVEL`: change the log level to adjust how much detail
  is captured. It defaults to `notice`; useful values include `info` and
  `debug`.
