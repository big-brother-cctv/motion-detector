FROM debian:bullseye

RUN apt update && \
    apt install -y motion curl ffmpeg && \
    apt clean

COPY motion.conf /etc/motion/motion.conf
COPY on_picture_save.sh /usr/local/bin/on_picture_save.sh
RUN chmod +x /usr/local/bin/on_picture_save.sh

CMD ["motion", "-n"]
