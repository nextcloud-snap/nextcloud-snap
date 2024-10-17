#!/bin/sh -e

# This is required by richdocuments so that it does not break installations.
# See https://github.com/nextcloud/richdocuments/issues/3780#issuecomment-2257677440
"$SNAP"/bin/redis-cli -s /tmp/sockets/redis.sock FLUSHDB
