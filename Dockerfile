FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    motion \
    curl \
    jq \
    ffmpeg \
    ca-certificates \
    python3 \
    python3-pip \
    python3-numpy \
    python3-pil \
    && pip install --no-cache-dir --break-system-packages onnxruntime \
    && rm -rf /var/lib/apt/lists/*

COPY motion.conf /etc/motion/motion.conf
COPY on_picture_save.sh /usr/local/bin/on_picture_save.sh
COPY on_event_end.sh /usr/local/bin/on_event_end.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY detect_objects.py /usr/local/bin/detect_objects.py
RUN chmod +x /usr/local/bin/on_picture_save.sh \
             /usr/local/bin/on_event_end.sh \
             /usr/local/bin/entrypoint.sh \
             /usr/local/bin/detect_objects.py

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

