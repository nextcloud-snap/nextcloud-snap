#!/bin/bash

# Starting from Version 28 Nextcloud recommends to set a default time window for resource heavy background jobs.
# See https://docs.nextcloud.com/server/28/admin_manual/configuration_server/background_jobs_configuration.html#maintenance-window-start

# Path to config.php file
config_file="/var/snap/nextcloud/current/nextcloud/config/config.php"

# Searching text (config name)
search_text="maintenance_window_start"

# New config text
insert_text="  'maintenance_window_start' => 1,"

# Check if config name exists
if grep -q "$search_text" "$config_file"; then
    echo "The text '$search_text' is already available in the config file '$config_file'."
else
    # Paste the the default config value in the last line
    sed -i '$i\'"$insert_text" "$config_file"
    echo "The text '$insert_text' has been added to the config file '$config_file'."
fi
