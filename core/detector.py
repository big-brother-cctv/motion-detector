"""Performs motion detection based on a video stream."""

import cv2
import time
from config.settings import STREAM_URL, MOTION_SENSITIVITY, MOTION_COUNT_THRESHOLD
from utils.capture import save_frame
from notifications.discord import notify_discord

def detect_motion():
    """
    Start the motion detection loop using frame differencing.

    Captures and sends a notification when the motion counter reaches the threshold.
    """
    print(f"Connecting to stream at {STREAM_URL}")
    cap = cv2.VideoCapture(STREAM_URL)
    time.sleep(2)

    ret, frame1 = cap.read()
    ret, frame2 = cap.read()

    motion_counter = 0

    while cap.isOpened():
        diff = cv2.absdiff(frame1, frame2)
        gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        _, thresh = cv2.threshold(blur, 20, 255, cv2.THRESH_BINARY)
        dilated = cv2.dilate(thresh, None, iterations=3)
        contours, _ = cv2.findContours(dilated, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

        motion_detected = any(cv2.contourArea(c) >= MOTION_SENSITIVITY for c in contours)

        if motion_detected:
            motion_counter += 1
            print(f"📈 Motion counter: {motion_counter}/{MOTION_COUNT_THRESHOLD}")

            if motion_counter >= MOTION_COUNT_THRESHOLD:
                print("🚨 Motion threshold reached! Capturing...")
                filename = save_frame(frame2)
                notify_discord("🚨 Motion detected 📸", image_path=filename)
                motion_counter = 0
        else:
            if motion_counter > 0:
                print("🔁 Motion lost, counter reset.")
            motion_counter = 0

        frame1 = frame2
        ret, frame2 = cap.read()
        if not ret:
            break

    cap.release()
