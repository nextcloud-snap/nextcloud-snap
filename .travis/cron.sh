#!/bin/bash

latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
latest_stable13_url="https://download.nextcloud.com/server/daily/latest-stable13.tar.bz2"
latest_stable14_url="https://download.nextcloud.com/server/daily/latest-stable14.tar.bz2"
latest_stable15_url="https://download.nextcloud.com/server/daily/latest-stable15.tar.bz2"

rewrite_snapcraft_yaml()
{
	# Since we're rewriting the source, we need to also remove the source-checksum.
        perl -0777 -i -pe "s|(.*source:\s+).*download.nextcloud.com.*?(\n.*?source-checksum:).*?\n|\1$1\2 ''\n|igs" snap/snapcraft.yaml
	sed -ri "s|(^version:\s+).*$|\1$2|" snap/snapcraft.yaml
}

request_build()
{
	branch_name="$1"
	url="$2"
	version="$3"
	commit_message="$4"

	git checkout -b "$1" "origin/${TRAVIS_BRANCH}"

	# Rewrite the snapcraft.yaml to pull the requested source
	rewrite_snapcraft_yaml "$url" "$version"

	# Commit the changes and push to begin the build.
	git add .
	git commit -m "$commit_message"
	git push deploy "$branch_name" --force
}

today="$(date +%F)"

echo "Requesting build of latest master..."
request_build \
	"latest-master" "$latest_master_url" "master-$today" \
	"From CI: Use Nextcloud latest master"

echo "Requesting build of latest 13..."
request_build \
	"latest-13" "$latest_stable13_url" "13-$today" \
	"From CI: Use Nextcloud latest 13"

echo "Requesting build of latest 14..."
request_build \
	"latest-14" "$latest_stable14_url" "14-$today" \
	"From CI: Use Nextcloud latest 14"

echo "Requesting build of latest 15..."
request_build \
	"latest-15" "$latest_stable15_url" "15-$today" \
	"From CI: Use Nextcloud latest 15"
