#!/bin/sh
#
# Version 32.0.8snap3 introduced MySQL v8.4, which disables `mysql_native_password`
# by default. Let's make sure that our users are migrated to use
# `caching_sha2_password`.
set -e

# shellcheck source=src/mysql/utilities/mysql-utilities
. "$SNAP/utilities/mysql-utilities"

root_password="$(sed -rn 's/password=(.*)/\1/p' "$MYSQL_ROOT_OPTION_FILE")"
nextcloud_password="$(mysql_get_nextcloud_password)"

"$SNAP"/bin/run-mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$root_password';
ALTER USER 'nextcloud'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$nextcloud_password';
SQL
