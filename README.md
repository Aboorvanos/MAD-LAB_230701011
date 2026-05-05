# Real-Time Screen Fatigue Monitoring System
## with Mobile Dashboard Using Computer Vision and Flutter

A real-time fatigue detection system that uses **computer vision** (OpenCV + MediaPipe) to monitor eye closure and blink patterns through a webcam, and streams the status to a **Flutter mobile dashboard** via a REST API.

---

## 📁 Project Structure

```
fatigue-monitor/
├── backend/                        # Python Computer Vision Backend
│   ├── app.py                      # Main app: Flask API + Webcam loop
│   ├── fatigue_detector.py         # Core detection: EAR, blinks, fatigue
│   └── requirements.txt            # Python dependencies
│
├── flutter_app/                    # Flutter Mobile Dashboard
│   ├── lib/
│   │   ├── main.dart               # App entry point & theme
│   │   ├── models/
│   │   │   └── fatigue_data.dart   # Data model for API response
│   │   ├── services/
│   │   │   └── api_service.dart    # HTTP client for Flask API
│   │   ├── screens/
│   │   │   ├── home_screen.dart    # Main dashboard UI
│   │   │   └── settings_dialog.dart# Backend URL settings
│   │   └── widgets/
│   │       ├── status_card.dart    # Animated status display
│   │       ├── metric_tile.dart    # Individual metric card
│   │       └── fatigue_gauge.dart  # Circular fatigue score gauge
│   ├── android/
│   │   └── app/src/main/
│   │       └── AndroidManifest.xml # Permissions
│   └── pubspec.yaml                # Flutter dependencies
│
└── README.md                       # This file
```

---

## 🔧 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.9+ | Backend runtime |
| pip | latest | Python package manager |
| Flutter SDK | 3.10+ | Mobile app framework |
| Android Studio | 2023+ | Flutter IDE + Android emulator |
| Webcam | any | Video input for face detection |

---

## 🚀 Step-by-Step Setup Instructions

### PART 1: Python Backend Setup

#### Step 1: Create a Virtual Environment (Recommended)

```bash
cd fatigue-monitor/backend

# Create virtual environment
python -m venv venv

# Activate it
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate
```

#### Step 2: Install Dependencies

```bash
pip install -r requirements.txt
```

#### Step 3: Run the Backend

```bash
python app.py
```

You should see:
```
=======================================================
  Real-Time Screen Fatigue Monitoring System
=======================================================
[INFO] Flask API starting on http://0.0.0.0:5000
[INFO] Status endpoint: http://localhost:5000/status
[INFO] Webcam opened (index=0)
[INFO] Press 'q' to quit, 'r' to reset counters
```

#### Step 4: Test the API

Open a browser or use curl:
```bash
curl http://localhost:5000/status
```

Expected response:
```json
{
  "status": "Normal",
  "ear": 0.3012,
  "blink_count": 5,
  "blink_rate": 12.3,
  "fatigue_score": 8.5,
  "face_detected": true
}
```

---

### PART 2: Flutter App Setup

#### Step 1: Open in Android Studio

1. Open Android Studio
2. Select **File → Open** → navigate to `fatigue-monitor/flutter_app`
3. Wait for Gradle sync and Flutter plugin initialization

#### Step 2: Install Dependencies

```bash
cd fatigue-monitor/flutter_app
flutter pub get
```

#### Step 3: Configure the Backend URL

The app connects to the backend using these defaults:

| Device Type | Default URL | Why |
|-------------|-------------|-----|
| Android Emulator | `http://10.0.2.2:5000` | `10.0.2.2` maps to host `localhost` |
| Physical Android | `http://<YOUR_PC_IP>:5000` | Use your PC's local IP |
| iOS Simulator | `http://localhost:5000` | Direct localhost access |

You can change this in the app's **Settings** (gear icon in the top bar).

**To find your PC's IP:**
```bash
# Windows
ipconfig
# macOS/Linux
ifconfig | grep "inet "
```

#### Step 4: Run the App

1. Start an **Android Emulator** or connect a **physical device**
2. Make sure the Python backend is already running
3. Run the Flutter app:

```bash
flutter run
```

Or press the **Run** button (▶) in Android Studio.

#### Step 5: Use the App

1. Tap **"Start Monitoring"** to begin polling the backend
2. The dashboard shows:
   - **Status**: Green (Normal) or Red (Fatigue)
   - **Fatigue Score**: Circular gauge (0–100)
   - **EAR Value**: Current Eye Aspect Ratio
   - **Blink Count**: Total blinks detected
   - **Blink Rate**: Blinks per minute
3. When fatigue is detected, a **red alert snackbar** appears with **haptic vibration**

---

## 🧠 How It Works

### Eye Aspect Ratio (EAR)

The EAR formula measures how "open" an eye is:

```
EAR = (||p2 - p6|| + ||p3 - p5||) / (2 × ||p1 - p4||)
```

- **p1, p4**: Horizontal eye corners (left/right)
- **p2, p6** and **p3, p5**: Vertical eyelid pairs (top/bottom)
- When eyes are open: EAR ≈ 0.25–0.40
- When eyes are closed: EAR < 0.20

### Fatigue Detection Logic

```
IF (eyes closed > 20 consecutive frames) → FATIGUE
OR (blink rate > 25 blinks/minute)       → FATIGUE
ELSE                                      → NORMAL
```

### Fatigue Score (0–100)

Calculated from three components:
- **EAR Component** (0–40 pts): How far below the threshold
- **Blink Rate Component** (0–30 pts): How excessive the blink rate is
- **Closure Duration** (0–30 pts): How long eyes have been continuously closed

---

## 🔌 API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | Returns current fatigue data (JSON) |
| `/health` | GET | Health check (always returns 200) |
| `/reset` | POST | Reset blink count and fatigue score |

### `/status` Response Schema

```json
{
  "status": "Normal | Fatigue | No Face",
  "ear": 0.3012,
  "blink_count": 42,
  "blink_rate": 15.2,
  "fatigue_score": 23.5,
  "face_detected": true
}
```

---

## ⚠️ Common Errors and Fixes

### Backend Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `Could not open webcam` | Wrong camera index | Change `CAMERA_INDEX` in `app.py` to `1` or `2` |
| `ModuleNotFoundError: mediapipe` | Missing dependency | Run `pip install -r requirements.txt` |
| `Address already in use` | Port 5000 in use | Change `FLASK_PORT` in `app.py` or kill the other process |
| Low FPS (<15) | Slow hardware | Reduce `FRAME_WIDTH`/`FRAME_HEIGHT` in `app.py` |
| No face detected | Poor lighting | Improve lighting; face the camera directly |

### Flutter Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection refused` | Backend not running | Start the Python backend first |
| `Cleartext HTTP traffic not permitted` | Android security policy | Already handled in `AndroidManifest.xml` (`usesCleartextTraffic=true`) |
| `SocketException` on physical device | Wrong IP address | Use your PC's local IP (not `localhost` or `10.0.2.2`) |
| Build fails | Missing dependencies | Run `flutter pub get` and restart IDE |
| `XMLHttpRequest error` on web | CORS issue | Already handled with `flask-cors` |

---

## 💡 Suggestions to Improve Accuracy

1. **Calibration Phase**: Add a 10-second calibration at startup where the user keeps eyes open. Use the measured EAR as the personal threshold instead of a fixed 0.25.

2. **Temporal Smoothing**: Apply a moving average filter (e.g., over 5 frames) to the EAR to reduce noise from brief measurement glitches.

3. **Head Pose Estimation**: Use MediaPipe's additional landmarks to detect head tilt/yawn, adding another fatigue signal.

4. **Yawn Detection**: Use mouth aspect ratio (MAR) with mouth landmarks to detect yawning as an additional fatigue indicator.

5. **PERCLOS Metric**: Implement the Percentage of Eye Closure (PERCLOS) over a 1-minute sliding window — the gold standard in drowsiness research.

6. **Adaptive Thresholds**: Adjust EAR threshold dynamically based on the user's baseline EAR (people have different eye shapes).

7. **Machine Learning**: Train a lightweight classifier (SVM or small neural network) on the combined features (EAR, blink rate, PERCLOS, MAR) for more robust classification.

8. **Data Logging**: Save session data (timestamps, EAR values, blink events) to a CSV for post-session analysis and trend tracking.

---

## 🌟 Novelty & Features

| Feature | Description |
|---------|-------------|
| **No Deep Learning Training** | Uses geometric ratios (EAR) — works instantly, no GPU needed |
| **Fatigue Score** | Composite 0–100 score from multiple indicators |
| **Real-time Desktop HUD** | Overlay with EAR, blink count, status, and score bar |
| **Mobile Dashboard** | Beautiful Flutter app with animated gauge and color-coded status |
| **Haptic Alerts** | Phone vibration when fatigue is detected |
| **Configurable Backend URL** | In-app settings for easy device setup |
| **Clean Architecture** | Separated detection logic, API layer, UI components |
| **Cross-Platform Ready** | Flutter app runs on Android, iOS, and Web |

---

## 📄 License

This project is provided for educational and research purposes.
