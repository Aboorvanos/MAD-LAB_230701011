import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/fatigue_data.dart';
import '../services/api_service.dart';

/// Detailed Stats Screen showing all fatigue metrics with history graphs.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiService _api = ApiService();
  FatigueData _data = FatigueData.idle;
  bool _isLoading = true;
  bool _isConnected = false;
  Timer? _pollTimer;

  // History for charts (last 30 data points)
  final List<double> _earHistory = [];
  final List<double> _fatigueHistory = [];
  final List<double> _blinkRateHistory = [];
  static const int _maxHistory = 30;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final result = await _api.fetchStatus();
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _data = result;
        _isLoading = false;
        _isConnected = true;

        // Append to history
        _earHistory.add(result.ear);
        _fatigueHistory.add(result.fatigueScore);
        _blinkRateHistory.add(result.blinkRate);

        // Trim to max
        if (_earHistory.length > _maxHistory) {
          _earHistory.removeAt(0);
        }
        if (_fatigueHistory.length > _maxHistory) {
          _fatigueHistory.removeAt(0);
        }
        if (_blinkRateHistory.length > _maxHistory) {
          _blinkRateHistory.removeAt(0);
        }
      });
    } else {
      setState(() {
        _isLoading = false;
        _isConnected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Detailed Stats'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF58A6FF)),
                    SizedBox(height: 16),
                    Text(
                      'Fetching data...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              )
            : !_isConnected
                ? _buildErrorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Status Banner ──
                        _buildStatusBanner(),
                        const SizedBox(height: 20),

                        // ── All Metrics List ──
                        _buildMetricDetailCard(
                          icon: Icons.remove_red_eye_rounded,
                          iconColor: const Color(0xFF58A6FF),
                          title: 'Eye Aspect Ratio (EAR)',
                          value: _data.ear.toStringAsFixed(4),
                          subtitle: _data.ear < 0.25
                              ? 'Below threshold — eyes closing'
                              : 'Above threshold — eyes open',
                          subtitleColor: _data.ear < 0.25
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF7EE787),
                        ),
                        const SizedBox(height: 12),

                        _buildMetricDetailCard(
                          icon: Icons.touch_app_rounded,
                          iconColor: const Color(0xFFD2A8FF),
                          title: 'Total Blink Count',
                          value: '${_data.blinkCount}',
                          subtitle: 'Since last reset',
                          subtitleColor: Colors.white54,
                        ),
                        const SizedBox(height: 12),

                        _buildMetricDetailCard(
                          icon: Icons.speed_rounded,
                          iconColor: const Color(0xFFFFAA5E),
                          title: 'Blink Rate',
                          value:
                              '${_data.blinkRate.toStringAsFixed(1)} blinks/min',
                          subtitle: _data.blinkRate > 20
                              ? 'Normal range'
                              : 'Below normal — possible drowsiness',
                          subtitleColor: _data.blinkRate > 20
                              ? const Color(0xFF7EE787)
                              : const Color(0xFFFFAA5E),
                        ),
                        const SizedBox(height: 12),

                        _buildMetricDetailCard(
                          icon: Icons.psychology_rounded,
                          iconColor: _data.fatigueScore < 30
                              ? const Color(0xFF7EE787)
                              : _data.fatigueScore < 60
                                  ? const Color(0xFFFFAA5E)
                                  : const Color(0xFFFF6B6B),
                          title: 'Fatigue Score',
                          value:
                              '${_data.fatigueScore.toStringAsFixed(1)} / 100',
                          subtitle: _fatigueLabel(_data.fatigueScore),
                          subtitleColor: _data.fatigueScore < 30
                              ? const Color(0xFF7EE787)
                              : _data.fatigueScore < 60
                                  ? const Color(0xFFFFAA5E)
                                  : const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(height: 12),

                        _buildMetricDetailCard(
                          icon: Icons.face_rounded,
                          iconColor: _data.faceDetected
                              ? const Color(0xFF7EE787)
                              : const Color(0xFFFF6B6B),
                          title: 'Face Detection',
                          value: _data.faceDetected ? 'Detected' : 'Not Found',
                          subtitle: _data.faceDetected
                              ? 'Face is visible to the camera'
                              : 'No face in camera view',
                          subtitleColor: _data.faceDetected
                              ? const Color(0xFF7EE787)
                              : const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(height: 12),

                        _buildMetricDetailCard(
                          icon: Icons.monitor_heart_rounded,
                          iconColor: _data.isFatigued
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF7EE787),
                          title: 'Current Status',
                          value: _data.status,
                          subtitle: _data.isFatigued
                              ? 'Consider taking a break'
                              : 'Everything looks good',
                          subtitleColor: _data.isFatigued
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF7EE787),
                        ),
                        const SizedBox(height: 28),

                        // ── Charts ──
                        if (_earHistory.length > 1) ...[
                          _buildChartCard(
                            title: 'EAR HISTORY',
                            data: _earHistory,
                            color: const Color(0xFF58A6FF),
                            minY: 0.0,
                            maxY: 0.5,
                            thresholdY: 0.25,
                          ),
                          const SizedBox(height: 16),

                          _buildChartCard(
                            title: 'FATIGUE SCORE HISTORY',
                            data: _fatigueHistory,
                            color: const Color(0xFFFF6B6B),
                            minY: 0.0,
                            maxY: 100.0,
                            thresholdY: 50.0,
                          ),
                          const SizedBox(height: 16),

                          _buildChartCard(
                            title: 'BLINK RATE HISTORY',
                            data: _blinkRateHistory,
                            color: const Color(0xFFFFAA5E),
                            minY: 0.0,
                            maxY: 80.0,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── Error State ──

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Cannot reach backend',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your Flask server is running',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchData();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58A6FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Banner ──

  Widget _buildStatusBanner() {
    final isFatigued = _data.isFatigued;
    final color = isFatigued ? const Color(0xFFFF6B6B) : const Color(0xFF7EE787);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isFatigued
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _data.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFatigued
                      ? 'High fatigue levels detected'
                      : 'All metrics within normal range',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric Detail Card ──

  Widget _buildMetricDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart Card ──

  Widget _buildChartCard({
    required String title,
    required List<double> data,
    required Color color,
    required double minY,
    required double maxY,
    double? thresholdY,
  }) {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: thresholdY != null
                    ? ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: thresholdY,
                            color: Colors.white.withOpacity(0.2),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ],
                      )
                    : const ExtraLinesData(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.25),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF21262D),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(2),
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }

  String _fatigueLabel(double score) {
    if (score < 20) return 'Alert — No fatigue detected';
    if (score < 40) return 'Mild fatigue — Monitor closely';
    if (score < 60) return 'Moderate fatigue — Consider a break';
    if (score < 80) return 'High fatigue — Break recommended';
    return 'Severe fatigue — Immediate break needed';
  }
}
