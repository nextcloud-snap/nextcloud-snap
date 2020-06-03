#!/bin/sh -e

# This does a lot of stuff, but what we really care about is the fact that it
# regenerates the asset caches. This is required because these caches are
# stored alongside the data, which is unversioned. Without clearing the caches
# on starup, a revert would try to use a newer version's CSS, for example.
occ -n maintenance:repair
