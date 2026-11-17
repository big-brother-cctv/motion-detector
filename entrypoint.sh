#!/bin/sh
set -e

mkdir -p /tmp/motion_images /tmp/motion/conf.d /tmp/models /etc/motion/models

# Preparar modelo YOLOv8n ONNX ligero si no existe
if [ ! -f /etc/motion/models/yolov8n.onnx ] && [ ! -f /tmp/models/yolov8n.onnx ]; then
  echo "[AI SETUP] Descargando modelo ligero YOLOv8n ONNX para filtro de personas/vehículos..."
  curl -sL --connect-timeout 10 -o /tmp/models/yolov8n.onnx https://huggingface.co/Xuban/yolo_weights_database/resolve/main/yolov8n.onnx 2>/dev/null || true
fi
if [ -f /tmp/models/yolov8n.onnx ] && [ ! -f /etc/motion/models/yolov8n.onnx ]; then
  ln -sf /tmp/models/yolov8n.onnx /etc/motion/models/yolov8n.onnx 2>/dev/null || true
fi

API_URL="${API_URL:-http://api:8080/api/alerts}"
API_BASE=$(echo "$API_URL" | sed 's|/api/alerts.*||')
CONFIG_URL="${API_BASE}/api/motion/config"

if [ -z "${INTERNAL_TOKEN:-}" ]; then
  echo "[MOTION DETECTOR] AVISO: INTERNAL_TOKEN no definido; la API rechazará la consulta de configuración y las alertas."
fi

fetch_config() {
  curl -sf --connect-timeout "$1" -H "Authorization: Bearer ${INTERNAL_TOKEN:-}" "${CONFIG_URL}" 2>/dev/null || true
}

# Los valores vienen de la API y se escriben en ficheros de configuración de Motion y en la
# línea de comando de on_picture_save: NUNCA se deben aceptar sin validar (inyección de directivas).
# Se usan patrones `case` (no grep) porque grep valida línea a línea y un valor con
# salto de línea ("ab\non_event_start ...") pasaría la comprobación.
is_safe_name() {
  case "$1" in ""|?|*[!A-Za-z0-9_.-]*) return 1 ;; esac
  [ "${#1}" -le 48 ]
}
is_uint() {
  case "$1" in ""|*[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 7 ]
}
is_decimal() {
  case "$1" in ""|.*|*.|*.*.*|*[!0-9.]*) return 1 ;; esac
  return 0
}
is_ai_mode() {
  case "$1" in all|person|vehicles|animals|none|disabled) return 0 ;; esac
  return 1
}
is_rtsp_url() {
  case "$1" in rtsp://?*|rtsps://?*) ;; *) return 1 ;; esac
  case "$1" in *[!A-Za-z0-9._~:@%/?=\&+-]*) return 1 ;; esac
  return 0
}

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
framerate 10
netcam_params rtsp_transport=tcp
noise_level 32
noise_tune on
despeckle_filter EedDl
picture_quality 85
EOF

  configured=0
  if [ -n "$json" ] && which jq >/dev/null 2>&1; then
    count=$(printf '%s' "$json" | jq -r '.cameras | length' 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
      i=0
      while [ "$i" -lt "$count" ]; do
        cam_name=$(printf '%s' "$json" | jq -r ".cameras[$i].name // empty")
        cam_id=$(printf '%s' "$json" | jq -r ".cameras[$i].id // ($i + 1)")
        rtsp_url=$(printf '%s' "$json" | jq -r ".cameras[$i].rtspUrl // empty")
        cam_res=$(printf '%s' "$json" | jq -r ".cameras[$i].resolution // empty")
        threshold=$(printf '%s' "$json" | jq -r ".cameras[$i].threshold // 350")
        frames=$(printf '%s' "$json" | jq -r ".cameras[$i].frames // 2")
        cooldown=$(printf '%s' "$json" | jq -r ".cameras[$i].cooldown // 15")
        ai_mode=$(printf '%s' "$json" | jq -r ".cameras[$i].aiMode // \"all\"")
        ai_conf=$(printf '%s' "$json" | jq -r ".cameras[$i].aiConfidence // 0.28")
        enabled=$(printf '%s' "$json" | jq -r ".cameras[$i].enabled // true")

        if [ "$enabled" = "true" ] && [ -n "$cam_name" ]; then
          if ! is_safe_name "$cam_name" || ! is_uint "$cam_id" || ! is_rtsp_url "$rtsp_url" \
             || ! is_uint "$threshold" || ! is_uint "$frames" || ! is_uint "$cooldown" \
             || ! is_decimal "$ai_conf" || ! is_ai_mode "$ai_mode"; then
            echo "[MOTION][SECURITY] Cámara #$i ignorada: valores no válidos en la configuración recibida de la API"
            i=$((i + 1))
            continue
          fi
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
framerate 10
netcam_params rtsp_transport=tcp
threshold ${threshold}
minimum_motion_frames ${frames}
picture_output best
on_picture_save /usr/local/bin/on_picture_save.sh %f ${cam_name} ${ai_conf} ${ai_mode} ${cooldown}
CAM_EOF
          echo "[MOTION] Cámara unificada configurada: ${cam_name} (ID: ${cam_id}, res: nativa) - Umbral: ${threshold}px, IA: ${ai_mode} (${ai_conf})"
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
framerate 10
netcam_params rtsp_transport=tcp
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
  RESP=$(fetch_config 2)
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
    NEW_RESP=$(fetch_config 3)
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
