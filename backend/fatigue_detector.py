"""
Fatigue Detection Module
========================
Handles face landmark detection, EAR calculation, blink counting,
and fatigue classification using MediaPipe FaceLandmarker (Tasks API).

Updated for MediaPipe >= 0.10.30 which uses the Tasks API
instead of the deprecated mp.solutions interface.
"""

import os
import urllib.request
import numpy as np
import mediapipe as mp
import time
from collections import deque

# ─── Model Download ─────────────────────────────────────────────────────────

MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_landmarker/face_landmarker/float16/latest/face_landmarker.task"
)
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "face_landmarker.task")


def _ensure_model():
    """Download the face landmarker model if not already present."""
    if not os.path.exists(MODEL_PATH):
        print(f"[INFO] Downloading face landmarker model...")
        print(f"[INFO] Saving to: {MODEL_PATH}")
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
        print("[INFO] Model downloaded successfully.")


class FatigueDetector:
    """Real-time fatigue detector using Eye Aspect Ratio (EAR)."""

    # MediaPipe Face Mesh landmark indices for eyes
    # These indices are the same across all MediaPipe face mesh versions (478 landmarks)
    LEFT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
    RIGHT_EYE_INDICES = [362, 385, 387, 263, 373, 380]

    def __init__(
        self,
        ear_threshold: float = 0.25,
        closed_frames_threshold: int = 20,
        blink_rate_threshold: int = 25,  # blinks per minute
        blink_rate_window: int = 60,     # seconds to track blink rate
    ):
        """
        Initialize the FatigueDetector.

        Args:
            ear_threshold: EAR value below which the eye is considered closed.
            closed_frames_threshold: Number of consecutive frames with closed
                eyes to trigger fatigue.
            blink_rate_threshold: Blinks per minute above which fatigue is
                triggered.
            blink_rate_window: Time window (seconds) to track blink rate.
        """
        self.ear_threshold = ear_threshold
        self.closed_frames_threshold = closed_frames_threshold
        self.blink_rate_threshold = blink_rate_threshold

        # Download model if needed
        _ensure_model()

        # Create FaceLandmarker using the Tasks API
        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = mp.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
        VisionRunningMode = mp.tasks.vision.RunningMode

        options = FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=MODEL_PATH),
            running_mode=VisionRunningMode.IMAGE,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
            min_tracking_confidence=0.5,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
        )
        self.landmarker = FaceLandmarker.create_from_options(options)

        # State tracking
        self._closed_frame_counter = 0
        self._blink_count = 0
        self._total_blink_count = 0
        self._eye_was_closed = False
        self._blink_timestamps = deque()
        self._blink_rate_window = blink_rate_window

        # Current values (thread-safe reads from Flask)
        self.current_ear = 0.0
        self.current_status = "NORMAL"
        self.current_fatigue_score = 0.0
        self.face_detected = False

    @staticmethod
    def _calculate_ear(eye_landmarks: list[np.ndarray]) -> float:
        """
        Calculate the Eye Aspect Ratio (EAR) for a single eye.

        EAR = (||p2 - p6|| + ||p3 - p5||) / (2 * ||p1 - p4||)

        Args:
            eye_landmarks: List of 6 (x, y) coordinate arrays:
                [p1, p2, p3, p4, p5, p6]

        Returns:
            The EAR value (float).
        """
        p1, p2, p3, p4, p5, p6 = eye_landmarks

        # Vertical distances
        vertical_1 = np.linalg.norm(p2 - p6)
        vertical_2 = np.linalg.norm(p3 - p5)

        # Horizontal distance
        horizontal = np.linalg.norm(p1 - p4)

        if horizontal == 0:
            return 0.0

        ear = (vertical_1 + vertical_2) / (2.0 * horizontal)
        return ear

    def _extract_eye_landmarks(
        self, landmarks, indices: list[int], img_w: int, img_h: int
    ) -> list[np.ndarray]:
        """
        Extract eye landmark coordinates from MediaPipe landmarks.

        Args:
            landmarks: List of NormalizedLandmark from FaceLandmarker result.
            indices: List of 6 landmark indices for one eye.
            img_w: Image width in pixels.
            img_h: Image height in pixels.

        Returns:
            List of 6 numpy arrays with (x, y) pixel coordinates.
        """
        coords = []
        for idx in indices:
            lm = landmarks[idx]
            x = int(lm.x * img_w)
            y = int(lm.y * img_h)
            coords.append(np.array([x, y], dtype=np.float64))
        return coords

    def _update_blink_rate(self) -> float:
        """
        Calculate blinks per minute using the sliding window.

        Returns:
            Current blink rate (blinks per minute).
        """
        now = time.time()
        # Remove old timestamps outside the window
        while (
            self._blink_timestamps
            and now - self._blink_timestamps[0] > self._blink_rate_window
        ):
            self._blink_timestamps.popleft()

        if not self._blink_timestamps:
            return 0.0

        elapsed = now - self._blink_timestamps[0]
        if elapsed <= 0:
            return 0.0

        # Blinks per minute
        bpm = (len(self._blink_timestamps) / elapsed) * 60.0
        return bpm

    def _compute_fatigue_score(self, avg_ear: float, blink_rate: float) -> float:
        """
        Compute a fatigue score from 0 (alert) to 100 (severely fatigued).

        Factors:
          - How far EAR is below the threshold (eye droopiness)
          - How high the blink rate is relative to threshold
          - Duration of continuous eye closure

        Args:
            avg_ear: Current average EAR value.
            blink_rate: Current blinks per minute.

        Returns:
            Fatigue score (0–100).
        """
        score = 0.0

        # EAR component (0–40 points)
        if avg_ear < self.ear_threshold:
            ear_deficit = (self.ear_threshold - avg_ear) / self.ear_threshold
            score += min(ear_deficit * 80.0, 40.0)

        # Blink rate component (0–30 points)
        if blink_rate > 0:
            rate_ratio = blink_rate / self.blink_rate_threshold
            if rate_ratio > 1.0:
                score += min((rate_ratio - 1.0) * 30.0, 30.0)

        # Closed frames component (0–30 points)
        if self._closed_frame_counter > 0:
            closure_ratio = (
                self._closed_frame_counter / self.closed_frames_threshold
            )
            score += min(closure_ratio * 30.0, 30.0)

        return min(score, 100.0)

    def process_frame(self, frame: np.ndarray) -> dict:
        """
        Process a single video frame and return fatigue data.

        Args:
            frame: BGR image (numpy array from OpenCV).

        Returns:
            Dictionary with keys:
                - ear (float): Average EAR value
                - blink_count (int): Total blink count
                - blink_rate (float): Blinks per minute
                - status (str): "NORMAL" or "FATIGUE DETECTED"
                - fatigue_score (float): Score 0–100
                - face_detected (bool)
        """
        import cv2

        img_h, img_w = frame.shape[:2]

        # Convert BGR → RGB for MediaPipe
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Create MediaPipe Image from numpy array
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)

        # Detect face landmarks using the Tasks API
        result = self.landmarker.detect(mp_image)

        if not result.face_landmarks:
            self.face_detected = False
            self.current_status = "NO FACE"
            return {
                "ear": 0.0,
                "blink_count": self._total_blink_count,
                "blink_rate": 0.0,
                "status": "NO FACE",
                "fatigue_score": 0.0,
                "face_detected": False,
            }

        self.face_detected = True
        face_landmarks = result.face_landmarks[0]  # First face

        # Extract eye landmarks
        left_eye = self._extract_eye_landmarks(
            face_landmarks, self.LEFT_EYE_INDICES, img_w, img_h
        )
        right_eye = self._extract_eye_landmarks(
            face_landmarks, self.RIGHT_EYE_INDICES, img_w, img_h
        )

        # Calculate EAR
        left_ear = self._calculate_ear(left_eye)
        right_ear = self._calculate_ear(right_eye)
        avg_ear = (left_ear + right_ear) / 2.0
        self.current_ear = avg_ear

        # Blink detection
        if avg_ear < self.ear_threshold:
            self._closed_frame_counter += 1
            self._eye_was_closed = True
        else:
            if self._eye_was_closed:
                # Eye just reopened → register a blink
                self._total_blink_count += 1
                self._blink_timestamps.append(time.time())
                self._eye_was_closed = False
            self._closed_frame_counter = 0

        # Blink rate
        blink_rate = self._update_blink_rate()

        # Fatigue detection
        is_fatigued = (
            self._closed_frame_counter >= self.closed_frames_threshold
            or blink_rate > self.blink_rate_threshold
        )

        status = "FATIGUE DETECTED" if is_fatigued else "NORMAL"
        self.current_status = status

        # Fatigue score
        fatigue_score = self._compute_fatigue_score(avg_ear, blink_rate)
        self.current_fatigue_score = fatigue_score

        return {
            "ear": round(avg_ear, 4),
            "blink_count": self._total_blink_count,
            "blink_rate": round(blink_rate, 1),
            "status": status,
            "fatigue_score": round(fatigue_score, 1),
            "face_detected": True,
        }

    def get_eye_landmarks_for_drawing(
        self, frame: np.ndarray
    ) -> tuple[list, list] | None:
        """
        Get pixel-coordinate eye landmarks for overlay drawing.

        Args:
            frame: BGR image.

        Returns:
            Tuple of (left_eye_coords, right_eye_coords), each a list
            of (x, y) integer tuples, or None if no face detected.
        """
        import cv2

        img_h, img_w = frame.shape[:2]
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = self.landmarker.detect(mp_image)

        if not result.face_landmarks:
            return None

        lm = result.face_landmarks[0]

        def to_pixel(indices):
            return [
                (int(lm[i].x * img_w), int(lm[i].y * img_h))
                for i in indices
            ]

        return to_pixel(self.LEFT_EYE_INDICES), to_pixel(self.RIGHT_EYE_INDICES)

    def reset(self):
        """Reset all counters and state."""
        self._closed_frame_counter = 0
        self._blink_count = 0
        self._total_blink_count = 0
        self._eye_was_closed = False
        self._blink_timestamps.clear()
        self.current_ear = 0.0
        self.current_status = "NORMAL"
        self.current_fatigue_score = 0.0
        self.face_detected = False
