#!/usr/bin/env python3
"""
Lightweight Event-Driven Object Detector for Big Brother CCTV.
Uses ONNX Runtime CPU to classify snapshots triggered by Motion daemon.
Zero memory footprint when idle. Designed for Celeron N3450 / low-resource nodes.
"""
import sys
import os
import numpy as np
from PIL import Image

MODEL_PATH = os.environ.get("AI_MODEL_PATH", "/etc/motion/models/yolov8n.onnx")
CONF_THRESHOLD = float(os.environ.get("AI_CONF_THRESHOLD", "0.40"))
TARGET_CLASSES = os.environ.get(
    "AI_TARGET_CLASSES", "person,car,truck,bus,motorcycle,bicycle,dog,cat"
).lower().split(",")

# Standard COCO 80 class labels
COCO_CLASSES = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
    "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
    "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
    "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
    "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
    "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
    "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
]

def detect(image_path: str):
    if not os.path.exists(image_path):
        return True, "motion"

    if not os.path.exists(MODEL_PATH):
        # Fallback: if model file is not present yet, do not lose alarm
        sys.stderr.write(f"[AI] Model file not found at {MODEL_PATH}, bypassing AI filter.\n")
        return True, "motion"

    try:
        import onnxruntime as ort

        # Run ONNX inference on CPU with 2 threads max to leave room for other apps
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 2
        opts.inter_op_num_threads = 1
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

        session = ort.InferenceSession(
            MODEL_PATH,
            sess_options=opts,
            providers=["CPUExecutionProvider"]
        )
        input_meta = session.get_inputs()[0]
        input_type = input_meta.type
        dtype = np.float16 if "float16" in input_type else np.float32

        # Load and resize image to 640x640 for YOLOv8
        img = Image.open(image_path).convert("RGB")
        img_resized = img.resize((640, 640), Image.Resampling.BILINEAR)
        img_data = (np.array(img_resized, dtype=np.float32) / 255.0).astype(dtype)
        # Transpose from (H, W, C) to (1, C, H, W)
        img_data = np.transpose(img_data, (2, 0, 1))
        input_tensor = np.expand_dims(img_data, axis=0)

        outputs = session.run(None, {input_meta.name: input_tensor})
        predictions = outputs[0]  # shape: (1, 84, 8400)

        # Transpose to (8400, 84) and compute in float32
        preds = predictions[0].T.astype(np.float32)
        scores = preds[:, 4:]  # (8400, 80)

        class_ids = np.argmax(scores, axis=1)
        confidences = np.max(scores, axis=1)

        # Filter by threshold and target classes
        target_indices = [
            i for i, name in enumerate(COCO_CLASSES) if name in TARGET_CLASSES
        ]
        mask = (confidences >= CONF_THRESHOLD) & np.isin(class_ids, target_indices)

        if not np.any(mask):
            return False, "no_target"

        best_idx = np.argmax(confidences * mask)
        best_class = COCO_CLASSES[class_ids[best_idx]]
        best_conf = float(confidences[best_idx])
        label = f"{best_class} ({int(best_conf * 100)}%)"
        return True, label

    except Exception as e:
        sys.stderr.write(f"[AI] Error during detection: {e}\n")
        # On error, allow alert to pass so real incidents are never missed
        return True, "motion"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: detect_objects.py <image_path>")
        sys.exit(2)

    image_path = sys.argv[1]
    has_target, label = detect(image_path)
    if has_target:
        print(f"LABEL={label}")
        sys.exit(0)
    else:
        print("NO_TARGET")
        sys.exit(1)
