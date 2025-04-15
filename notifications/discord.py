import requests
import os
import io
from config.settings import DISCORD_WEBHOOK_URL

def notify_discord(message, image_path=None, image_bytes=None):
    """
    Send a message to a Discord webhook, optionally with an image.

    Args:
        message (str): The message content to send.
        image_path (str, optional): Path to the image file to attach.
        image_bytes (BytesIO, optional): In-memory image to attach.
    """
    if not DISCORD_WEBHOOK_URL:
        print("⚠️ No DISCORD_WEBHOOK_URL set, skipping Discord notification.")
        return

    data = {"content": message}
    files = {}

    # If image is in memory, use image_bytes
    if image_bytes:
        files["file"] = ("motion.jpg", image_bytes, "image/jpeg")
    # If image is in disk, use image_path
    elif image_path and os.path.exists(image_path):
        files["file"] = open(image_path, "rb")

    try:
        response = requests.post(DISCORD_WEBHOOK_URL, data=data, files=files if files else None)
        response.raise_for_status()
        print("✅ Notification sent to Discord.")
    except Exception as e:
        print("❌ Error sending to Discord:", e)
    finally:
        if files:
            if isinstance(files["file"], io.BytesIO):
                # No need to close BytesIO, it's in memory
                pass
            else:
                files["file"].close()
