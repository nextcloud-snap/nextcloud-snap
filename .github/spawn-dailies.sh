#!/bin/bash

latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
latest_stable20_url="https://download.nextcloud.com/server/daily/latest-stable20.tar.bz2"
latest_stable21_url="https://download.nextcloud.com/server/daily/latest-stable21.tar.bz2"
latest_stable22_url="https://download.nextcloud.com/server/daily/latest-stable22.tar.bz2"

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

	git checkout -b "$1" "origin/${GITHUB_REF_NAME}"

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

echo "Requesting build of latest 20..."
request_build \
	"latest-20" "$latest_stable20_url" "20-$today" \
	"From CI: Use Nextcloud latest 20"

echo "Requesting build of latest 21..."
request_build \
	"latest-21" "$latest_stable21_url" "21-$today" \
	"From CI: Use Nextcloud latest 21"

echo "Requesting build of latest 22..."
request_build \
	"latest-22" "$latest_stable22_url" "22-$today" \
	"From CI: Use Nextcloud latest 22"