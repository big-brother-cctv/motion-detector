FROM python:3.11-bullseye

ENV STREAM_URL=http://camera:5000/video_feed
ENV DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz

RUN apt-get update && apt-get install -y \
    libglib2.0-0 libsm6 libxext6 libxrender-dev ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN pip install -r requirements.txt --no-cache-dir --prefer-binary

CMD ["python", "motion_detector.py"]
