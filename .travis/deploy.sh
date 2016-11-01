#!/bin/bash

# Push our current branch up for normal releases
echo "Requesting build/deploy of $TRAVIS_BRANCH..."
git push deploy $TRAVIS_BRANCH --force
