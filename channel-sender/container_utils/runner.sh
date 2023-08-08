#!/bin/sh

trap "echo; exit" INT

# load any needed env vars
File=/app/config/env.sh 
if test -f "$File"; then
    . $File
fi

# run release
/app/bin/channel_sender_ex start
