"""
Fatigue Monitoring Backend
==========================
Flask API server + real-time OpenCV webcam fatigue detection.

Runs two concurrent tasks:
  1. Webcam loop with overlay (desktop display)
  2. Flask HTTP API serving /status for the Flutter app

Usage:
    python app.py
"""

import threading
import time
import cv2
import numpy as np
from flask import Flask, jsonify
from flask_cors import CORS
from fatigue_detector import FatigueDetector

# ─── Configuration ───────────────────────────────────────────────────────────

FLASK_HOST = "0.0.0.0"
FLASK_PORT = 5000
CAMERA_INDEX = 0           # 0 = default webcam
TARGET_FPS = 30
FRAME_WIDTH = 640
FRAME_HEIGHT = 480

# EAR & fatigue thresholds
EAR_THRESHOLD = 0.25
CLOSED_FRAMES_THRESHOLD = 20
BLINK_RATE_THRESHOLD = 25   # blinks/minute

# ─── Globals ─────────────────────────────────────────────────────────────────

detector = FatigueDetector(
    ear_threshold=EAR_THRESHOLD,
    closed_frames_threshold=CLOSED_FRAMES_THRESHOLD,
    blink_rate_threshold=BLINK_RATE_THRESHOLD,
)

# Latest data shared between webcam thread and Flask
latest_data: dict = {
    "status": "NORMAL",
    "ear": 0.0,
    "blink_count": 0,
    "blink_rate": 0.0,
    "fatigue_score": 0.0,
    "face_detected": False,
}
data_lock = threading.Lock()

# ─── Flask App ───────────────────────────────────────────────────────────────

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from Flutter


@app.route("/status", methods=["GET"])
def get_status():
    """
    Return the latest fatigue monitoring data as JSON.

    Response schema:
    {
        "status": "Normal" | "Fatigue" | "No Face",
        "ear": float,
        "blink_count": int,
        "blink_rate": float,
        "fatigue_score": float,
        "face_detected": bool
    }
    """
    with data_lock:
        # Map internal status strings to clean API strings
        raw_status = latest_data["status"]
        if raw_status == "FATIGUE DETECTED":
            api_status = "Fatigue"
        elif raw_status == "NO FACE":
            api_status = "No Face"
        else:
            api_status = "Normal"

        return jsonify({
            "status": api_status,
            "ear": latest_data["ear"],
            "blink_count": latest_data["blink_count"],
            "blink_rate": latest_data["blink_rate"],
            "fatigue_score": latest_data["fatigue_score"],
            "face_detected": latest_data["face_detected"],
        })


@app.route("/reset", methods=["POST"])
def reset():
    """Reset fatigue detector counters."""
    detector.reset()
    with data_lock:
        latest_data.update({
            "status": "NORMAL",
            "ear": 0.0,
            "blink_count": 0,
            "blink_rate": 0.0,
            "fatigue_score": 0.0,
            "face_detected": False,
        })
    return jsonify({"message": "Reset successful"})


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "running"})


# ─── Overlay Drawing ────────────────────────────────────────────────────────

def draw_overlay(frame: np.ndarray, data: dict) -> np.ndarray:
    """
    Draw a stylish HUD overlay on the webcam frame.

    Args:
        frame: The BGR image.
        data: Dict from FatigueDetector.process_frame().

    Returns:
        The frame with overlay drawn.
    """
    h, w = frame.shape[:2]
    status = data["status"]
    ear = data["ear"]
    blink_count = data["blink_count"]
    blink_rate = data["blink_rate"]
    fatigue_score = data["fatigue_score"]
    face_detected = data["face_detected"]

    # ── Background panel (semi-transparent) ──
    overlay = frame.copy()
    panel_h = 160
    cv2.rectangle(overlay, (0, 0), (w, panel_h), (0, 0, 0), -1)
    cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)

    # ── Status colors ──
    if status == "FATIGUE DETECTED":
        status_color = (0, 0, 255)       # Red
        status_text = "⚠ FATIGUE DETECTED"
    elif status == "NO FACE":
        status_color = (0, 165, 255)     # Orange
        status_text = "NO FACE DETECTED"
    else:
        status_color = (0, 255, 0)       # Green
        status_text = "NORMAL"

    # ── Title bar ──
    cv2.putText(
        frame, "FATIGUE MONITOR",
        (15, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2,
    )

    # ── Status ──
    cv2.putText(
        frame, f"Status: {status_text}",
        (15, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, status_color, 2,
    )

    # ── Metrics ──
    cv2.putText(
        frame, f"EAR: {ear:.3f}",
        (15, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1,
    )
    cv2.putText(
        frame, f"Blinks: {blink_count}",
        (200, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1,
    )
    cv2.putText(
        frame, f"Rate: {blink_rate:.1f} bpm",
        (380, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1,
    )

    # ── Fatigue score bar ──
    bar_x, bar_y = 15, 115
    bar_w, bar_h = 300, 20
    # Background
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_w, bar_y + bar_h),
                  (50, 50, 50), -1)
    # Fill
    fill_w = int((fatigue_score / 100.0) * bar_w)
    if fatigue_score < 30:
        bar_color = (0, 200, 0)
    elif fatigue_score < 60:
        bar_color = (0, 200, 255)
    else:
        bar_color = (0, 0, 255)
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + fill_w, bar_y + bar_h),
                  bar_color, -1)
    # Border
    cv2.rectangle(frame, (bar_x, bar_y), (bar_x + bar_w, bar_y + bar_h),
                  (255, 255, 255), 1)
    # Label
    cv2.putText(
        frame, f"Fatigue Score: {fatigue_score:.0f}%",
        (bar_x + bar_w + 10, bar_y + 15),
        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1,
    )

    # ── Bottom instruction ──
    cv2.putText(
        frame, "Press 'q' to quit  |  'r' to reset",
        (15, h - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (150, 150, 150), 1,
    )

    return frame


# ─── Webcam Loop (runs in main thread) ──────────────────────────────────────

def run_webcam():
    """
    Main webcam capture + processing loop.
    Displays the annotated video feed in an OpenCV window.
    """
    global latest_data

    cap = cv2.VideoCapture(CAMERA_INDEX)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)

    if not cap.isOpened():
        print("[ERROR] Could not open webcam. Check CAMERA_INDEX.")
        print("        Try changing CAMERA_INDEX to 1 or 2 in app.py")
        return

    print(f"[INFO] Webcam opened (index={CAMERA_INDEX})")
    print(f"[INFO] Resolution: {FRAME_WIDTH}x{FRAME_HEIGHT}")
    print("[INFO] Press 'q' to quit, 'r' to reset counters")

    frame_delay = 1.0 / TARGET_FPS
    fps_timer = time.time()
    fps_count = 0
    display_fps = 0

    while True:
        start_time = time.time()

        ret, frame = cap.read()
        if not ret:
            print("[WARNING] Failed to read frame. Retrying...")
            time.sleep(0.1)
            continue

        # Process frame
        data = detector.process_frame(frame)

        # Update shared data for Flask
        with data_lock:
            latest_data = data.copy()

        # Draw overlay
        frame = draw_overlay(frame, data)

        # FPS counter
        fps_count += 1
        if time.time() - fps_timer >= 1.0:
            display_fps = fps_count
            fps_count = 0
            fps_timer = time.time()

        cv2.putText(
            frame, f"FPS: {display_fps}",
            (frame.shape[1] - 120, 30),
            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2,
        )

        # Show frame
        cv2.imshow("Fatigue Monitor", frame)

        # Key handling
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            break
        elif key == ord("r"):
            detector.reset()
            print("[INFO] Counters reset")

        # Frame rate limiting
        elapsed = time.time() - start_time
        if elapsed < frame_delay:
            time.sleep(frame_delay - elapsed)

    cap.release()
    cv2.destroyAllWindows()
    print("[INFO] Webcam closed")


# ─── Entry Point ─────────────────────────────────────────────────────────────

def run_flask():
    """Run Flask in a background thread."""
    app.run(
        host=FLASK_HOST,
        port=FLASK_PORT,
        debug=True,
        use_reloader=False,
    )


if __name__ == "__main__":
    print("=" * 55)
    print("  Real-Time Screen Fatigue Monitoring System")
    print("=" * 55)
    print(f"[INFO] Flask API starting on http://{FLASK_HOST}:{FLASK_PORT}")
    print(f"[INFO] LAN endpoint:  http://192.168.137.251:{FLASK_PORT}/status")
    print(f"[INFO] Local endpoint: http://localhost:{FLASK_PORT}/status")
    print()

    # Start Flask in a daemon thread
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    # Give Flask a moment to start
    time.sleep(1)

    # Run webcam in main thread (OpenCV requires main thread on some OS)
    run_webcam()

    print("[INFO] Application exited")
