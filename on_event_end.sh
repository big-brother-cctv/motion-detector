#!/bin/bash

COOLDOWN_FILE="/tmp/motion_last_notification"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-30}"

if [ -z "$DISCORD_WEBHOOK" ]; then
  echo "DISCORD_WEBHOOK not set"
  exit 1
fi

FILE=$(ls -t /tmp/motion_images/*.jpg 2>/dev/null | head -n 1)

if [ -z "$FILE" ]; then
  echo "No image found to send"
  exit 0
fi

now=$(date +%s)
last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
diff=$((now - last))

if [ "$diff" -ge "$COOLDOWN_SECONDS" ]; then
  curl -F "file=@${FILE}" \
       -F "content=Cat detected!📸" \
       "$DISCORD_WEBHOOK"

  echo "$now" > "$COOLDOWN_FILE"
else
  echo "Notification skipped (cooldown: ${diff}s elapsed, requires ${COOLDOWN_SECONDS}s)"
fi
