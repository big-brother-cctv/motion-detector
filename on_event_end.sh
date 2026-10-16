#!/bin/bash

COOLDOWN_FILE="/tmp/motion_last_notification"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-15}"
API_URL="${API_URL:-http://api:8080/api/alerts}"
INTERNAL_TOKEN="${INTERNAL_TOKEN:-internal-token-dev}"
CAMERA_NAME="${CAMERA_NAME:-camera}"

FILE=$(ls -t /tmp/motion_images/*.jpg 2>/dev/null | head -n 1)

if [ -z "$FILE" ]; then
  echo "No image found to send"
  exit 0
fi

now=$(date +%s)
last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
diff=$((now - last))

if [ "$diff" -ge "$COOLDOWN_SECONDS" ]; then
  # 1. Enviar alerta local a la API propia de Big Brother (sin servicios de terceros)
  echo "Enviando alerta local a Big Brother API: $API_URL"
  curl -s -F "image=@${FILE}" \
       -F "camera_name=${CAMERA_NAME}" \
       -F "label=motion" \
       -F "token=${INTERNAL_TOKEN}" \
       "$API_URL"

  # 2. Opcional: webhook externo de respaldo si estuviera configurado
  if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -F "file=@${FILE}" \
         -F "content=🚨 Movimiento detectado en ${CAMERA_NAME}! 📸" \
         "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
  fi

  echo "$now" > "$COOLDOWN_FILE"
else
  echo "Alerta omitida (cooldown: ${diff}s transcurridos, requiere ${COOLDOWN_SECONDS}s)"
fi
