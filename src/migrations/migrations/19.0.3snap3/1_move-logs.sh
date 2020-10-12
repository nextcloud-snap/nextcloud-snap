#!/bin/sh -e
#
# Version 19.0.3snap3 introduced log rotation, and it also reorganized the log
# layout. Let's move any existing logs into place so we don't lose them.

mkdir -p "${SNAP_DATA}/logs"
chmod 750 "${SNAP_DATA}/logs"

apache_errors_log="$SNAP_DATA/apache/logs/error_log"
if [ -f "$apache_errors_log" ]; then
	mv "$apache_errors_log" "$SNAP_DATA/logs/apache_errors.log"
fi

php_errors_log="$SNAP_DATA/apache/logs/php_errors.log"
if [ -f "$php_errors_log" ]; then
	mv "$php_errors_log" "$SNAP_DATA/logs/php_errors.log"
fi

php_fpm_errors_log="$SNAP_DATA/php/php-fpm.log"
if [ -f "$php_fpm_errors_log" ]; then
	mv "$php_fpm_errors_log" "$SNAP_DATA/logs/php-fpm_errors.log"
fi

redis_log="$SNAP_DATA/redis/redis.log"
if [ -f "$redis_log" ]; then
	mv "$redis_log" "$SNAP_DATA/logs/redis.log"
fi

mysql_errors_log="$SNAP_DATA/mysql/error.log"
if [ -f "$mysql_errors_log" ]; then
	mv "$mysql_errors_log" "$SNAP_DATA/logs/mysql_errors.log"
fi

# The apache and php directories only existed to hold those logs, so we don't
# need them anymore
rm -rf "$SNAP_DATA/apache" "$SNAP_DATA/php"