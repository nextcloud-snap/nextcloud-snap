#!/bin/sh -e

# Technically convert-filecache-bigint should be run under maintenance mode, but
# there really isn't anything to go wrong on a fresh install, and the UX of enabling
# maintenance mode as soon as an admin account is created is awful.
occ -n db:convert-filecache-bigint