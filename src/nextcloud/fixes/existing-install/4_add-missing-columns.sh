#!/bin/sh -e

# This command can be run without putting Nextcloud into maintenance mode
occ -n db:add-missing-columns
