#!/bin/bash

# Need to work around https://github.com/thoughtbot/capybara-webkit/issues/494
# which requires a newer qt5 than that available in Trusty. Webkit was removed
# in 5.6 though, so stick with 5.5.
sudo add-apt-repository --yes ppa:beineri/opt-qt551-trusty
sudo apt update

# Also install xvfb since we're running headless in CI
sudo apt install --yes qt55-meta-minimal mesa-common-dev qt55webkit xvfb

# Finally, activate the Qt installation
source /opt/qt55/bin/qt55-env.sh

# In order to use rvm, we need a login shell. We need to install
# Ruby v2.4.0 (the older version that is the default doesn't handle
# the redirection that we test)
bash --login -c '
    rvm install 2.4.0
    rvm use 2.4.0
    cd tests
    gem install bundler
    bundle install --deployment
    bundle exec rake test
'
