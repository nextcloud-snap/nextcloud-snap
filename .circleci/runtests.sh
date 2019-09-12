#!/bin/sh

# Note that the tests require chrome and chromedriver, but the CircleCI machine
# executor image already contains both.

# In order to use rvm, we need a login shell. We need to install
# Ruby v2.4.0 (the older version that is the default doesn't handle
# the redirection that we test)
bash --login -c '
    rvm install 2.6.2
    rvm use 2.6.2
    cd tests
    gem update --system
    gem install bundler
    bundle install --deployment
    bundle exec rake test
'
