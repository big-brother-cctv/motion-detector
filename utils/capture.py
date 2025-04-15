"""Handles saving frames to disk."""

import cv2
import os
from datetime import datetime
from config.settings import OUTPUT_DIR

def save_frame(frame):
    """
    Save a frame to disk with a timestamp.

    Args:
        frame (numpy.ndarray): The image frame to save.

    Returns:
        str: Path to the saved image file.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.join(OUTPUT_DIR, f"motion_{timestamp}.jpg")
    cv2.imwrite(filename, frame)
    print(f"📸 Saved motion frame to {filename}")
    return filename
