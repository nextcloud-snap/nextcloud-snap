#!/bin/sh -e

# If Nextcloud just updated, it's possible that the upgrade process
# placed app update files, but didn't run the proper migrations for
# them. Run upgrade again to make sure
occ -n upgrade