"""Handles saving frames to disk."""

import cv2
import os
import io
from datetime import datetime
from config.settings import OUTPUT_DIR, SAVE_TO_DISK

def save_frame(frame):
    """
    Save a frame to disk or return it as BytesIO.

    Args:
        frame (numpy.ndarray): The image frame to save or convert.

    Returns:
        str | BytesIO: Path to the saved image file or in-memory image.
    """
    if SAVE_TO_DISK:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(OUTPUT_DIR, f"motion_{timestamp}.jpg")
        cv2.imwrite(filename, frame)
        print(f"📸 Saved motion frame to {filename}")
        return filename
    else:
        _, buffer = cv2.imencode('.jpg', frame)
        print("📸 Converted motion frame to in-memory image")
        return io.BytesIO(buffer.tobytes())
