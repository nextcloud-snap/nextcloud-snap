#!/bin/sh -e

# Check if config 'maintenance_window_start' doesn't exist or has no value set
if ! occ -n config:system:get maintenance_window_start; then
	# Set default 'maintenance_window_start' to 1 a.m. (UTC)
	occ -n config:system:set maintenance_window_start --value=1 --type=integer
fi