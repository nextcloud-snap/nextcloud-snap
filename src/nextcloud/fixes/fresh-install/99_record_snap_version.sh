#!/bin/sh -e

# shellcheck source=src/common/utilities/common-utilities
. "$SNAP/utilities/common-utilities"

# Record the snap version so we can notify when it's been updated
set_previous_snap_version "$SNAP_VERSION"
