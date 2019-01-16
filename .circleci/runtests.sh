#!/bin/sh

# Install dependencies for the gems
sudo apt install qt5-default libqt5webkit5-dev xvfb -y

# In order to use rvm, we need a login shell. We need to install
# Ruby v2.4.0 (the older version that is the default doesn't handle
# the redirection that we test)
bash --login -c '
    rvm install 2.4.0
    rvm use 2.4.0
    cd tests
    gem update --system
    gem install bundler
    bundle install --deployment
    bundle exec rake test
'
