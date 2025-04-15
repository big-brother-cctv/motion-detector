"""Configuration variables loaded from environment."""

import os

STREAM_URL = os.getenv("STREAM_URL", "http://camera.local/video_feed")
DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")
MOTION_SENSITIVITY = int(os.getenv("MOTION_SENSITIVITY", "2000"))
MOTION_COUNT_THRESHOLD = int(os.getenv("MOTION_COUNT_THRESHOLD", "10"))
OUTPUT_DIR = "./data"
# Ensure output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)
