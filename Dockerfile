FROM debian:bullseye

RUN apt update && \
    apt install -y motion curl ffmpeg && \
    apt clean

COPY motion.conf /etc/motion/motion.conf
COPY on_event_end.sh /usr/local/bin/on_event_end.sh
RUN chmod +x /usr/local/bin/on_event_end.sh

CMD ["motion", "-n"]
