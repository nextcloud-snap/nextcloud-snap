#!/bin/sh
set -e

# shellcheck source=src/common/utilities/common-utilities
. "$SNAP/utilities/common-utilities"

# Nextcloud 31 starts suggesting row format DYNAMIC in the database.
# This should be done in maintenance mode to prevent possible key conflicts on
# big tables, like oc_filecache. This way the db is not in use.
# Reference: https://github.com/nextcloud-snap/nextcloud-snap/issues/3093
"$SNAP"/bin/run-mysql nextcloud -Bse "SELECT JSON_ARRAYAGG(JSON_OBJECT('table_name', table_name, 'row_format', row_format)) FROM information_schema.tables WHERE table_schema = 'nextcloud' AND engine = 'InnoDB';" | jq -ecR 'fromjson? | .[]' | while read -r table_info; do
	table=$(echo "$table_info" | jq -r .table_name)
	format=$(echo "$table_info" | jq -r .row_format | tr '[:upper:]' '[:lower:]')

	if [ "${format}" != "dynamic" ]; then
		run_command "Setting row format for table $table to DYNAMIC" "$SNAP"/bin/run-mysql nextcloud -Bse "ALTER TABLE $table ROW_FORMAT = DYNAMIC;"
	fi
done
