#!/bin/sh -e

# Now explicitly update all apps, in case the upgrade step didn't do it
if occ -n app:update --all; then
	# app:update downloads and extracts the updates, but now we
	# need to run database migrations, etc. so run upgrade again
	occ -n upgrade
fi