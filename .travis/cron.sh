#!/bin/bash

latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
latest_stable_url="https://download.nextcloud.com/server/daily/latest-stable11.tar.bz2"

rewrite_snapcraft_yaml()
{
	# Since we're rewriting the source, we need to also remove the source-checksum.
        perl -0777 -i -pe "s|(.*source:\s+).*download.nextcloud.com.*?(\n.*?source-checksum:).*?\n|\1$1\2 ''\n|igs" snap/snapcraft.yaml
	sed -ri "s|(^version:\s+).*$|\1$2|" snap/snapcraft.yaml
}

echo "Requesting build of latest master..."
git checkout -b edge origin/${TRAVIS_BRANCH}

# Rewrite the snapcraft.yaml to pull from the latest master.
rewrite_snapcraft_yaml $latest_master_url "latest-master"

# Commit the changes and push to edge to begin the edge build.
git add .
git commit -m 'From CI: Use Nextcloud latest master'
git push deploy edge --force


echo "Requesting build of latest stable..."
git checkout -b beta origin/${TRAVIS_BRANCH}

# Now rewrite the snapcraft.yaml to pull from the latest stable v11.
rewrite_snapcraft_yaml $latest_stable_url "latest-stable11"

# Commit the changes and push to beta to begin the beta build.
git add .
git commit -m 'From CI: Use Nextcloud latest stable'
git push deploy beta --force
