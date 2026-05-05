/// Data model representing the fatigue status response from the backend.
class FatigueData {
  /// Current fatigue status: "Normal", "Fatigue", or "No Face".
  final String status;

  /// Average Eye Aspect Ratio (0.0–0.5 typical range).
  final double ear;

  /// Total blink count since last reset.
  final int blinkCount;

  /// Blinks per minute over the rolling window.
  final double blinkRate;

  /// Fatigue score from 0 (alert) to 100 (severely fatigued).
  final double fatigueScore;

  /// Whether a face is currently detected.
  final bool faceDetected;

  const FatigueData({
    required this.status,
    required this.ear,
    required this.blinkCount,
    required this.blinkRate,
    required this.fatigueScore,
    required this.faceDetected,
  });

  /// Create a [FatigueData] from the Flask API JSON response.
  factory FatigueData.fromJson(Map<String, dynamic> json) {
    return FatigueData(
      status: json['status'] as String? ?? 'Unknown',
      ear: (json['ear'] as num?)?.toDouble() ?? 0.0,
      blinkCount: (json['blink_count'] as num?)?.toInt() ?? 0,
      blinkRate: (json['blink_rate'] as num?)?.toDouble() ?? 0.0,
      fatigueScore: (json['fatigue_score'] as num?)?.toDouble() ?? 0.0,
      faceDetected: json['face_detected'] as bool? ?? false,
    );
  }

  /// Whether the user is currently fatigued.
  bool get isFatigued => status == 'Fatigue';

  /// Whether monitoring is active (face detected).
  bool get isActive => faceDetected;

  /// Default "idle" state before any data is received.
  static const FatigueData idle = FatigueData(
    status: 'Idle',
    ear: 0.0,
    blinkCount: 0,
    blinkRate: 0.0,
    fatigueScore: 0.0,
    faceDetected: false,
  );
}
