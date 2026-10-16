FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    motion \
    curl \
    ffmpeg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY motion.conf /etc/motion/motion.conf
COPY on_event_end.sh /usr/local/bin/on_event_end.sh
RUN chmod +x /usr/local/bin/on_event_end.sh

CMD ["motion", "-n"]
