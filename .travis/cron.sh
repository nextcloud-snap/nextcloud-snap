#!/bin/bash

latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
latest_stable11_url="https://download.nextcloud.com/server/daily/latest-stable11.tar.bz2"
latest_stable12_url="https://download.nextcloud.com/server/daily/latest-stable12.tar.bz2"

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


echo "Requesting build of latest 11..."
request_build \
	"latest-11" "$latest_stable11_url" "11-$today" \
	"From CI: Use Nextcloud latest 11"


echo "Requesting build of latest 12..."
request_build \
	"latest-12" "$latest_stable12_url" "12-$today" \
	"From CI: Use Nextcloud latest 12"
