#!/bin/bash

# Prepare to push to LP
echo "Setting up remote... "
git remote add deploy git+ssh://nextcloud-snappy-bot@git.launchpad.net/nextcloud-snap

# Push our current branch up for normal releases
echo "Requesting build/deploy of $TRAVIS_BRANCH..."
git push deploy $TRAVIS_BRANCH --force

# Spin off daily builds if Travis is running this as a cron event.
if [ "$TRAVIS_BRANCH" = "master" -a "$TRAVIS_EVENT_TYPE" = "cron" ]; then
	latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
	latest_stable_url="https://download.nextcloud.com/server/daily/latest-stable10.tar.bz2"

	echo "Requesting build of latest master..."

	# Rewrite the snapcraft.yaml to pull from the latest master.
	sed -ri "s|(source:\s+).*download.nextcloud.com.*$|\1$latest_master_url|" snapcraft.yaml
	
	# Commit the changes and push to edge to begin the edge build.
	git add .
	git commit -m 'From CI: Use Nextcloud latest master'
	git push deploy $TRAVIS_BRANCH:edge --force


	echo "Requesting build of latest stable..."

	# Now rewrite the snapcraft.yaml to pull from the latest stable v10.
	sed -ri "s|(source:\s+).*download.nextcloud.com.*$|\1$latest_stable_url|" snapcraft.yaml

	# Commit the changes and push to beta to begin the beta build.
	git add .
	git commit -m 'From CI: Use Nextcloud latest stable'
	git push deploy $TRAVIS_BRANCH:beta --force
fi
