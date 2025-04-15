#!/bin/bash

FILE=$1

if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "DISCORD_WEBHOOK not set"
  exit 1
fi

curl -F "file=@${FILE}" \
     -F "content=¡Movimiento detectado por Motion!" \
     "$DISCORD_WEBHOOK"
