import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fatigue_data.dart';
import '../services/api_service.dart';
import '../widgets/status_card.dart';
import '../widgets/metric_tile.dart';
import '../widgets/fatigue_gauge.dart';

/// Main home screen / dashboard of the Fatigue Dashboard app.
///
/// Handles polling the backend, displaying real-time fatigue data,
/// and triggering alerts when fatigue is detected.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();

  // State
  FatigueData _data = FatigueData.idle;
  bool _isMonitoring = false;
  bool _isConnected = false;
  bool _alertShown = false;
  Timer? _pollTimer;

  // Auto-retry state
  int _retryCountdown = 0;
  Timer? _retryTimer;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startMonitoring() {
    setState(() {
      _isMonitoring = true;
      _retryCountdown = 0;
    });
    _alertShown = false;

    // Poll every 2 seconds
    _pollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _fetchData());
    // Fetch immediately
    _fetchData();
  }

  void _stopMonitoring() {
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    _pulseController.stop();
    setState(() {
      _isMonitoring = false;
      _data = FatigueData.idle;
      _isConnected = false;
      _retryCountdown = 0;
    });
  }

  Future<void> _fetchData() async {
    final result = await _api.fetchStatus();
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _data = result;
        _isConnected = true;
      });

      // Fatigue alert handling
      if (result.isFatigued && !_alertShown) {
        _triggerFatigueAlert();
      } else if (!result.isFatigued) {
        _alertShown = false;
        _pulseController.stop();
        _pulseController.reset();
      }
      // Clear any retry countdown on success
      _retryTimer?.cancel();
      _retryCountdown = 0;
    } else {
      setState(() => _isConnected = false);
      _startRetryCountdown();
    }
  }

  // ── Auto-Retry ────────────────────────────────────────────────────────────

  void _startRetryCountdown() {
    if (_retryTimer?.isActive ?? false) return;
    setState(() => _retryCountdown = 5);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _retryCountdown--);
      if (_retryCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  void _triggerFatigueAlert() {
    _alertShown = true;

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Pulse animation on status card
    _pulseController.repeat(reverse: true);

    // Show "Take a Break" alert
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.coffee_rounded,
                    color: Color(0xFFFF6B6B), size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Take a Break!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Fatigue has been detected. You\'ve been staring at the screen for too long.\n\nPlease take a 5–10 minute break to rest your eyes.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.self_improvement_rounded, size: 18),
              label: const Text('I\'ll Rest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58A6FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );

      // Also show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fatigue detected! Please take a break.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> _resetCounters() async {
    final success = await _api.resetCounters();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Counters reset successfully'
                : 'Failed to reset counters',
          ),
          backgroundColor: success ? const Color(0xFF7EE787) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text('Fatigue Monitor'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              _isConnected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: _isConnected
                  ? const Color(0xFF7EE787)
                  : Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ),
          if (_isMonitoring)
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded, size: 22),
              onPressed: _resetCounters,
              tooltip: 'Reset counters',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Status Card ──
              ScaleTransition(
                scale: _data.isFatigued
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: StatusCard(
                  status: _data.status,
                  isConnected: _isConnected || !_isMonitoring,
                ),
              ),
              const SizedBox(height: 16),

              // ── Offline Banner ──
              if (_isMonitoring && !_isConnected)
                _buildOfflineBanner(),

              const SizedBox(height: 16),

              // ── Start / Stop Button ──
              _buildToggleButton(),
              const SizedBox(height: 24),

              // ── Fatigue Gauge ──
              if (_isMonitoring) ...[
                FatigueGauge(score: _data.fatigueScore),
                const SizedBox(height: 20),

                // ── Metrics Grid ──
                _buildMetricsGrid(),
                const SizedBox(height: 20),

                // ── EAR Progress Bar ──
                _buildEarBar(),
                const SizedBox(height: 24),
              ],

              // ── Navigation Buttons ──
              _buildNavButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1215),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFF6B6B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend Offline',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _retryCountdown > 0
                      ? 'Retrying in ${_retryCountdown}s...'
                      : 'Check your Wi-Fi connection',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFFFF6B6B),
            iconSize: 22,
            tooltip: 'Retry now',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: _isMonitoring
              ? [const Color(0xFFFF6B6B), const Color(0xFFEE5A5A)]
              : [const Color(0xFF58A6FF), const Color(0xFF388BFD)],
        ),
        boxShadow: [
          BoxShadow(
            color: (_isMonitoring
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF58A6FF))
                .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isMonitoring ? _stopMonitoring : _startMonitoring,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMonitoring
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        MetricTile(
          label: 'EAR VALUE',
          value: _data.ear.toStringAsFixed(3),
          icon: Icons.remove_red_eye_rounded,
          iconColor: const Color(0xFF58A6FF),
        ),
        MetricTile(
          label: 'BLINK COUNT',
          value: '${_data.blinkCount}',
          icon: Icons.touch_app_rounded,
          iconColor: const Color(0xFFD2A8FF),
        ),
        MetricTile(
          label: 'BLINK RATE',
          value: '${_data.blinkRate.toStringAsFixed(1)} /min',
          icon: Icons.speed_rounded,
          iconColor: const Color(0xFFFFAA5E),
        ),
        MetricTile(
          label: 'FACE',
          value: _data.faceDetected ? 'Detected' : 'None',
          icon: Icons.face_rounded,
          iconColor: _data.faceDetected
              ? const Color(0xFF7EE787)
              : const Color(0xFFFF6B6B),
        ),
      ],
    );
  }

  Widget _buildEarBar() {
    // Normalize EAR to 0–1 range (typical EAR is 0.15 – 0.40)
    final normalizedEar = ((_data.ear - 0.1) / 0.35).clamp(0.0, 1.0);
    final earColor =
        _data.ear < 0.25 ? const Color(0xFFFF6B6B) : const Color(0xFF7EE787);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EYE ASPECT RATIO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1,
                ),
              ),
              Text(
                _data.ear.toStringAsFixed(4),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: earColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Background
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Threshold marker
                Positioned(
                  left: ((0.25 - 0.1) / 0.35).clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 72),
                  child: Container(
                    width: 2,
                    height: 10,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                // Fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 10,
                  width: normalizedEar *
                      (MediaQuery.of(context).size.width - 72),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [earColor.withOpacity(0.8), earColor],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: earColor.withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Closed',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              Text(
                'Threshold: 0.25',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              Text(
                'Open',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Navigation Buttons ──

  Widget _buildNavButtons() {
    return Row(
      children: [
        Expanded(
          child: _navButton(
            icon: Icons.bar_chart_rounded,
            label: 'Detailed Stats',
            gradient: const [Color(0xFFD2A8FF), Color(0xFFB07EFF)],
            onTap: () => Navigator.pushNamed(context, '/stats'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _navButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            gradient: const [Color(0xFFFFAA5E), Color(0xFFE89040)],
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
