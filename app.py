import cv2
import requests
import time
import os
from datetime import datetime

# Configuration (Config Map)
STREAM_URL = os.getenv("STREAM_URL", "http://camera:5000/video_feed")
DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")
OUTPUT_DIR = "/data"
MOTION_SENSITIVITY = int(os.getenv("MOTION_SENSITIVITY", "1000"))

os.makedirs(OUTPUT_DIR, exist_ok=True)

def save_frame(frame):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(OUTPUT_DIR, f"motion_{timestamp}.jpg")
    cv2.imwrite(filename, frame)
    print(f"📸 Saved motion frame to {filename}")
    return filename

def notify_discord(message, image_path=None):
    if not DISCORD_WEBHOOK_URL:
        print("⚠️ No DISCORD_WEBHOOK_URL set, skipping Discord notification.")
        return

    data = {
        "content": message
    }

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

def detect_motion():
    print(f"Connecting to stream at {STREAM_URL}")
    cap = cv2.VideoCapture(STREAM_URL)
    time.sleep(2)

    ret, frame1 = cap.read()
    ret, frame2 = cap.read()

    while cap.isOpened():
        diff = cv2.absdiff(frame1, frame2)
        gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        _, thresh = cv2.threshold(blur, 20, 255, cv2.THRESH_BINARY)
        dilated = cv2.dilate(thresh, None, iterations=3)
        contours, _ = cv2.findContours(dilated, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

        motion_detected = False
        for contour in contours:
            if cv2.contourArea(contour) < MOTION_SENSITIVITY:
                continue
            motion_detected = True

        if motion_detected:
            print("🚨 Motion detected!")
            filename = save_frame(frame2)

            notify_discord("🚨 Movimiento detectado 📸", image_path=filename)

        frame1 = frame2
        ret, frame2 = cap.read()
        if not ret:
            break

    cap.release()

if __name__ == "__main__":
    detect_motion()
