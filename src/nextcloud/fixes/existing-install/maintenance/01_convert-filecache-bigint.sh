#!/bin/sh -e

# Unfortunately convert-filecache-bigint requires that Nextcloud be in maintenance
# mode, and can take some time.
occ -n db:convert-filecache-bigint