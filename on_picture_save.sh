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

# Validar tamaño mínimo de archivo (descartar JPEGs corruptos o truncados < 4KB)
FILE_SIZE=$(wc -c < "$FILE" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt 4000 ]; then
  echo "[DISCARD] Snapshot demasiado pequeño o corrupto (${FILE_SIZE} bytes): $FILE"
  rm -f "$FILE"
  exit 0
fi

# Detectar y descartar fotogramas verdes o negros producidos por anomalías del decodificador H.264
if which ffmpeg >/dev/null 2>&1 && which od >/dev/null 2>&1; then
  RGB=$(ffmpeg -nostdin -v error -i "$FILE" -vf "scale=1:1" -f rawvideo -pix_fmt rgb24 - 2>/dev/null | od -An -t u1 2>/dev/null)
  if [ -n "$RGB" ]; then
    set -- $RGB
    r=${1:-0}
    g=${2:-0}
    b=${3:-0}
    # YUV=0/sin sincronizar decodifica exactamente a R=0 G=138 B=0 (verde digital sólido)
    if [ "$r" -lt 25 ] && [ "$b" -lt 25 ] && [ "$g" -gt 60 ]; then
      echo "[DISCARD] Fotograma verde de artefacto digital descartado para [${CAMERA_NAME}] ($FILE - RGB: $r,$g,$b)"
      rm -f "$FILE"
      exit 0
    fi
    # Fotograma completamente negro (< 4 en todos los canales)
    if [ "$r" -lt 4 ] && [ "$g" -lt 4 ] && [ "$b" -lt 4 ]; then
      echo "[DISCARD] Fotograma negro vacío descartado para [${CAMERA_NAME}] ($FILE)"
      rm -f "$FILE"
      exit 0
    fi

    # Detectar y descartar bandas verticales / smear por pérdida de paquetes H.264 (filas inferiores casi idénticas)
    ROWS=$(ffmpeg -nostdin -v error -i "$FILE" -vf "scale=1:5" -f rawvideo -pix_fmt gray - 2>/dev/null | od -An -t u1 2>/dev/null)
    if [ -n "$ROWS" ]; then
      set -- $ROWS
      y1=${1:-0}; y2=${2:-0}; y3=${3:-0}; y4=${4:-0}; y5=${5:-0}
      d23=$(( y2 > y3 ? y2 - y3 : y3 - y2 ))
      d34=$(( y3 > y4 ? y3 - y4 : y4 - y3 ))
      d45=$(( y4 > y5 ? y4 - y5 : y5 - y4 ))
      if [ "$d23" -eq 0 ] && [ "$d34" -eq 0 ] && [ "$d45" -eq 0 ]; then
        echo "[DISCARD] Fotograma con barrido vertical (smear/macroblocks corruptos) descartado para [${CAMERA_NAME}] ($FILE - Rows: $y1 $y2 $y3 $y4 $y5)"
        rm -f "$FILE"
        exit 0
      fi
    fi

    # Detectar y descartar artefactos cromáticos por pérdida de macroblocks H.264 (bandas magenta/rosa o verde fosforito en bordes)
    EDGE_RGB=$(ffmpeg -nostdin -v error -i "$FILE" -vf "split=2[l][r]; [l]crop=in_w*0.2:in_h:0:0,scale=1:2[l2]; [r]crop=in_w*0.2:in_h:in_w*0.8:0,scale=1:2[r2]; [l2][r2]vstack" -f rawvideo -pix_fmt rgb24 - 2>/dev/null | od -An -t u1 2>/dev/null)
    if [ -n "$EDGE_RGB" ]; then
      set -- $EDGE_RGB
      while [ $# -ge 3 ]; do
        cr=$1; cg=$2; cb=$3
        shift 3
        # Ruido magenta/rosa por desincronización de crominancia U/V
        if [ "$cr" -gt 50 ] && [ "$cr" -gt $(( cg * 3 / 2 )) ] && [ "$cb" -gt $(( cg * 11 / 10 )) ]; then
          echo "[DISCARD] Fotograma con corrupción cromática magenta/rosa descartado para [${CAMERA_NAME}] ($FILE - RGB: $cr,$cg,$cb)"
          rm -f "$FILE"
          exit 0
        fi
        # Ruido verde por decodificación YUV fuera de rango
        if [ "$cg" -gt 60 ] && [ "$cg" -gt $(( cr * 3 / 2 )) ] && [ "$cg" -gt $(( cb * 3 / 2 )) ]; then
          echo "[DISCARD] Fotograma con corrupción cromática verde descartado para [${CAMERA_NAME}] ($FILE - RGB: $cr,$cg,$cb)"
          rm -f "$FILE"
          exit 0
        fi
      done
    fi
  fi
fi

now=$(date +%s)
last=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
diff=$((now - last))

if [ "$diff" -ge "$COOLDOWN_SECONDS" ]; then
  # -------------------------------------------------------------
  # Filtro de Inteligencia Artificial (YOLOv8 Nano en CPU)
  # -------------------------------------------------------------
  AI_ENABLED="${AI_ENABLED:-true}"
  LABEL="motion"

  if [ "$AI_ENABLED" = "true" ] && which python3 >/dev/null 2>&1 && [ -f /usr/local/bin/detect_objects.py ]; then
    AI_OUTPUT=$(python3 /usr/local/bin/detect_objects.py "$FILE" 2>/dev/null)
    AI_STATUS=$?

    if [ "$AI_STATUS" -eq 1 ]; then
      echo "[AI FILTER] Snapshot descartado para [${CAMERA_NAME}]: No se detectó ninguna persona o vehículo relevante."
      rm -f "$FILE"
      exit 0
    elif [ "$AI_STATUS" -eq 0 ]; then
      DETECTED_LABEL=$(echo "$AI_OUTPUT" | grep "^LABEL=" | cut -d= -f2-)
      if [ -n "$DETECTED_LABEL" ]; then
        LABEL="$DETECTED_LABEL"
        echo "[AI FILTER] ¡Objetivo confirmado para [${CAMERA_NAME}]!: $LABEL"
      fi
    fi
  fi

  # Alerta local 100% self-hosted
  echo "Enviando snapshot de [${CAMERA_NAME}] ($FILE) [Label: ${LABEL}] a Big Brother API: $API_URL"
  curl -s -F "image=@${FILE}" \
       -F "camera_name=${CAMERA_NAME}" \
       -F "label=${LABEL}" \
       -F "token=${INTERNAL_TOKEN}" \
       "$API_URL"

  if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -F "file=@${FILE}" \
         -F "content=🚨 Alerta de Seguridad [${CAMERA_NAME}] - Detectado: **${LABEL}** 📸" \
         "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
  fi

  echo "$now" > "$COOLDOWN_FILE"
else
  echo "Alerta omitida (cooldown: ${diff}s transcurridos, requiere ${COOLDOWN_SECONDS}s)"
fi

# Limpiar de inmediato el fichero temporal procesado para no acumular basura en disco
rm -f "$FILE"

# Limpieza de seguridad de posibles ficheros residuales antiguos (>2 minutos)
find /tmp/motion_images -type f -name "*.jpg" -mmin +2 -delete 2>/dev/null || true

