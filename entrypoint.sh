#!/bin/sh
set -e

mkdir -p /tmp/motion_images

CONF_SOURCE="/etc/motion/motion.conf"
CONF_FILE="/tmp/motion.conf"

NETCAM_URL="${NETCAM_URL:-${STREAM_URL:-rtsp://mediamtx:8554/${CAMERA_NAME:-camera}}}"
CAMERA_NAME="${CAMERA_NAME:-camera}"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
FRAMERATE="${FRAMERATE:-30}"
THRESHOLD="${THRESHOLD:-800}"

echo "=========================================================="
echo "[MOTION DETECTOR] Iniciando servicio de vigilancia táctica"
echo "[MOTION DETECTOR] Nodo cámara: ${CAMERA_NAME}"
echo "[MOTION DETECTOR] Origen RTSP: ${NETCAM_URL}"
echo "[MOTION DETECTOR] API Alertas: ${API_URL:-http://api:8080/api/alerts}"
echo "=========================================================="

# Copiar a /tmp/motion.conf para evitar errores de "Device or resource busy"
# causados por sed -i sobre archivos montados en Kubernetes (ConfigMap / subPath bind mounts)
if [ -f "$CONF_SOURCE" ]; then
  cp "$CONF_SOURCE" "$CONF_FILE"
fi

if [ -f "$CONF_FILE" ]; then
  sed -i "s|^netcam_url .*|netcam_url ${NETCAM_URL}|" "$CONF_FILE"
  sed -i "s|^camera_name .*|camera_name ${CAMERA_NAME}|" "$CONF_FILE"
  sed -i "s|^width .*|width ${WIDTH}|" "$CONF_FILE"
  sed -i "s|^height .*|height ${HEIGHT}|" "$CONF_FILE"
  sed -i "s|^framerate .*|framerate ${FRAMERATE}|" "$CONF_FILE"
  sed -i "s|^threshold .*|threshold ${THRESHOLD}|" "$CONF_FILE"
fi

exec motion -n -c "$CONF_FILE"
