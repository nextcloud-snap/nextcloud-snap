#!/bin/bash

latest_master_url="https://download.nextcloud.com/server/daily/latest-master.tar.bz2"
latest_stable25_url="https://download.nextcloud.com/server/daily/latest-stable25.tar.bz2"
latest_stable26_url="https://download.nextcloud.com/server/daily/latest-stable26.tar.bz2"
latest_stable27_url="https://download.nextcloud.com/server/daily/latest-stable27.tar.bz2"

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

echo "Requesting build of latest 25..."
request_build \
	"latest-25" "$latest_stable25_url" "25-$today" \
	"From CI: Use Nextcloud latest 25"

echo "Requesting build of latest 26..."
request_build \
	"latest-26" "$latest_stable26_url" "26-$today" \
	"From CI: Use Nextcloud latest 26"

echo "Requesting build of latest 27..."
request_build \
	"latest-27" "$latest_stable27_url" "27-$today" \
	"From CI: Use Nextcloud latest 27"
