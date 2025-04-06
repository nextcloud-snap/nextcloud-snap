#!/bin/sh -e

# Nextcloud 31 starts suggesting row format DYNAMIC in the database.
# This should be done in maintenance mode to prevent possible key conflicts on
# big tables, like oc_filecache. This way the db is not used for the time beeing.
# Reference: https://github.com/nextcloud-snap/nextcloud-snap/issues/3093
"$SNAP"/bin/run-mysql nextcloud -Bse "
SELECT CONCAT('ALTER TABLE ', TABLE_NAME, ' ROW_FORMAT = DYNAMIC;')
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'nextcloud'
AND ENGINE = 'InnoDB'
AND TABLE_NAME NOT IN (
    SELECT TABLE_NAME FROM INFORMATION_SCHEMA.INNODB_TABLES
    WHERE NAME LIKE 'nextcloud/%' AND ROW_FORMAT = 'DYNAMIC'
)
" | "$SNAP"/bin/run-mysql nextcloud