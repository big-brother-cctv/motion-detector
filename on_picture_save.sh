#!/bin/bash

FILE=$1
CAMERA_NAME="${2:-${CAMERA_NAME:-camera}}"
COOLDOWN_FILE="/tmp/motion_last_notification_${CAMERA_NAME}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-15}"
API_URL="${API_URL:-http://api:8080/api/alerts}"
INTERNAL_TOKEN="${INTERNAL_TOKEN:-internal-token-pro}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ] || [ ! -s "$FILE" ]; then
  exit 0
fi

now=$(date +%s)
last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
diff=$((now - last))

if [ "$diff" -ge "$COOLDOWN_SECONDS" ]; then
  # Alerta local 100% self-hosted
  echo "Enviando snapshot de [${CAMERA_NAME}] ($FILE) a Big Brother API: $API_URL"
  curl -s -F "image=@${FILE}" \
       -F "camera_name=${CAMERA_NAME}" \
       -F "label=motion" \
       -F "token=${INTERNAL_TOKEN}" \
       "$API_URL"

  if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -F "file=@${FILE}" \
         -F "content=🚨 Movimiento detectado en ${CAMERA_NAME}! 📸" \
         "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
  fi

  echo "$now" > "$COOLDOWN_FILE"
else
  echo "Alerta omitida (cooldown: ${diff}s transcurridos, requiere ${COOLDOWN_SECONDS}s)"
fi

# Limpieza periódica de fotos antiguas en /tmp/motion_images (>10 minutos)
find /tmp/motion_images -name "*.jpg" -mmin +10 -delete 2>/dev/null || true

