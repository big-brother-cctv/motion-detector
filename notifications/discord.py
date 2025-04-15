"""Sends notifications to Discord."""

import requests
import os
from config.settings import DISCORD_WEBHOOK_URL

def notify_discord(message, image_path=None):
    """
    Send a message to a Discord webhook, optionally with an image.

    Args:
        message (str): The message content to send.
        image_path (str, optional): Path to the image file to attach.
    """
    if not DISCORD_WEBHOOK_URL:
        print("⚠️ No DISCORD_WEBHOOK_URL set, skipping Discord notification.")
        return

    data = {"content": message}
    files = {}

    if image_path and os.path.exists(image_path):
        files["file"] = open(image_path, "rb")

    try:
        response = requests.post(DISCORD_WEBHOOK_URL, data=data, files=files if files else None)
        response.raise_for_status()
        print("✅ Notification sent to Discord.")
    except Exception as e:
        print("❌ Error sending to Discord:", e)
    finally:
        if files:
            files["file"].close()
