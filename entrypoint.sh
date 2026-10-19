#!/bin/sh
set -e

mkdir -p /tmp/motion_images /tmp/motion/conf.d

API_URL="${API_URL:-http://api:8080/api/alerts}"
API_BASE=$(echo "$API_URL" | sed 's|/api/alerts.*||')
CONFIG_URL="${API_BASE}/api/motion/config"

generate_configs() {
  json="$1"
  rm -f /tmp/motion/conf.d/*.conf

  cat <<EOF > /tmp/motion.conf
daemon off
stream_localhost off
webcontrol_port 8083
webcontrol_localhost off
picture_output best
event_gap 10
movie_output off
camera_dir /tmp/motion/conf.d
framerate 5
netcam_params rtsp_transport=tcp,buffer_size=2048000,max_delay=500000
noise_level 32
noise_tune on
despeckle_filter EedDl
picture_quality 85
EOF

  configured=0
  if [ -n "$json" ] && which jq >/dev/null 2>&1; then
    count=$(echo "$json" | jq -r '.cameras | length' 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
      i=0
      while [ "$i" -lt "$count" ]; do
        cam_name=$(echo "$json" | jq -r ".cameras[$i].name // empty")
        cam_id=$(echo "$json" | jq -r ".cameras[$i].id // ($i + 1)")
        rtsp_url=$(echo "$json" | jq -r ".cameras[$i].rtspUrl // empty")
        cam_res=$(echo "$json" | jq -r ".cameras[$i].resolution // empty")
        threshold=$(echo "$json" | jq -r ".cameras[$i].threshold // 350")
        frames=$(echo "$json" | jq -r ".cameras[$i].frames // 2")
        enabled=$(echo "$json" | jq -r ".cameras[$i].enabled // true")

        if [ "$enabled" = "true" ] && [ -n "$cam_name" ]; then
          mkdir -p "/tmp/motion_images/${cam_name}"
          
          if [ -z "$cam_res" ] && which ffprobe >/dev/null 2>&1; then
            cam_res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "${rtsp_url}" 2>/dev/null | tail -n 1 || true)
          fi

          res_config=""
          if echo "$cam_res" | grep -q '^[0-9]\+x[0-9]\+$'; then
            w=$(echo "$cam_res" | cut -d'x' -f1)
            h=$(echo "$cam_res" | cut -d'x' -f2)
            res_config="width ${w}
height ${h}"
          fi

          cat <<CAM_EOF > "/tmp/motion/conf.d/camera_${cam_name}.conf"
camera_id ${cam_id}
camera_name ${cam_name}
target_dir /tmp/motion_images/${cam_name}
picture_filename ${cam_name}_%Y-%m-%d_%H-%M-%S
netcam_url ${rtsp_url}
framerate 5
netcam_params rtsp_transport=tcp,buffer_size=2048000,max_delay=500000
${res_config}
threshold ${threshold}
minimum_motion_frames ${frames}
picture_output best
on_picture_save /usr/local/bin/on_picture_save.sh %f ${cam_name}
CAM_EOF
          echo "[MOTION] Cámara unificada configurada: ${cam_name} (ID: ${cam_id}, ${rtsp_url}, res: ${cam_res:-auto}) - Umbral: ${threshold}px, 5fps"
          configured=$((configured + 1))
        fi
        i=$((i + 1))
      done
    fi
  fi

  # Si no hay cámaras dinámicas de la API, usar la cámara por defecto de variables de entorno
  if [ "$configured" -eq 0 ]; then
    DEFAULT_NAME="${CAMERA_NAME:-camera}"
    DEFAULT_URL="${NETCAM_URL:-${STREAM_URL:-rtsp://mediamtx:8554/${DEFAULT_NAME}}}"
    mkdir -p "/tmp/motion_images/${DEFAULT_NAME}"
    cat <<DEF_EOF > "/tmp/motion/conf.d/camera_${DEFAULT_NAME}.conf"
camera_id 1
camera_name ${DEFAULT_NAME}
target_dir /tmp/motion_images/${DEFAULT_NAME}
picture_filename ${DEFAULT_NAME}_%Y-%m-%d_%H-%M-%S
netcam_url ${DEFAULT_URL}
framerate 5
netcam_params rtsp_transport=tcp,buffer_size=2048000,max_delay=500000
threshold ${THRESHOLD:-350}
minimum_motion_frames ${MIN_MOTION_FRAMES:-2}
picture_output best
on_picture_save /usr/local/bin/on_picture_save.sh %f ${DEFAULT_NAME}
DEF_EOF
    echo "[MOTION] Modo fallback/local: ${DEFAULT_NAME} (${DEFAULT_URL})"
  fi
}

echo "=========================================================="
echo "[MOTION DETECTOR] Daemon Centralizado Unificado Multi-Cámara"
echo "[MOTION DETECTOR] Consultando API: ${CONFIG_URL}"
echo "=========================================================="

RESP=""
for attempt in 1 2 3; do
  RESP=$(curl -s --connect-timeout 2 "${CONFIG_URL}" 2>/dev/null || true)
  if [ -n "$RESP" ]; then
    break
  fi
  sleep 1
done

generate_configs "$RESP"

# Sincronizador en segundo plano: detecta nuevas cámaras o cambios de umbral cada 15 segundos
(
  LAST_HASH=$(echo "$RESP" | md5sum 2>/dev/null | awk '{print $1}')
  while true; do
    sleep 15
    NEW_RESP=$(curl -s --connect-timeout 3 "${CONFIG_URL}" 2>/dev/null || true)
    if [ -n "$NEW_RESP" ]; then
      NEW_HASH=$(echo "$NEW_RESP" | md5sum 2>/dev/null | awk '{print $1}')
      if [ -n "$LAST_HASH" ] && [ "$NEW_HASH" != "$LAST_HASH" ]; then
        echo "[MOTION DETECTOR] Cambio detectado en configuración de cámaras. Reconfigurando en caliente..."
        generate_configs "$NEW_RESP"
        curl -s http://127.0.0.1:8083/0/action/restart >/dev/null 2>&1 || true
      fi
      LAST_HASH="$NEW_HASH"
    fi
  done
) &

exec motion -n -c /tmp/motion.conf
