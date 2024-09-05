#!/bin/sh

trap "echo; exit" INT

# load any needed env vars
File=/app/config/env.sh 
if test -f "$File"; then
    echo "Loading env vars from ${File}"
    . $File
fi

# run release
/app/rel/adf_bridge/bin/adf_bridge start
