#!/bin/sh -e

# shellcheck source=src/nextcloud/utilities/nextcloud-utilities
. "$SNAP/utilities/nextcloud-utilities"
# shellcheck source=src/common/utilities/common-utilities
. "$SNAP/utilities/common-utilities"

previous_version="$(get_previous_snap_version)"
if [ "$previous_version" != "$SNAP_VERSION" ]; then
	message="The Nextcloud snap updated itself to version $SNAP_VERSION. We"
	message="$message are dedicated to ensuring these updates work amazingly"
	message="$message well, but in the unlikely event something broke,"
	message="$message remember you can revert the update with a single"
	message="$message command:\n\n"
	message="$message    $ sudo snap revert nextcloud\n\n"
	message="$message Please also don't forget to log an issue:"
	message="$message https://github.com/nextcloud/nextcloud-snap"

	run_command \
		"Notifying admins of update from ${previous_version:-unknown version} to $SNAP_VERSION" \
		nextcloud_notify_admins \
			"Nextcloud updated" "$(printf "%b" "$message")" || true

	set_previous_snap_version "$SNAP_VERSION"
fi
