import 'package:flutter/material.dart';

/// A glassmorphic card that displays the current fatigue status
/// with animated color transitions.
class StatusCard extends StatelessWidget {
  final String status;
  final bool isConnected;

  const StatusCard({
    super.key,
    required this.status,
    required this.isConnected,
  });

  Color _statusColor() {
    if (!isConnected) return Colors.grey;
    switch (status) {
      case 'Fatigue':
        return const Color(0xFFFF6B6B);
      case 'No Face':
        return const Color(0xFFFFAA5E);
      case 'Normal':
        return const Color(0xFF7EE787);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    if (!isConnected) return Icons.cloud_off_rounded;
    switch (status) {
      case 'Fatigue':
        return Icons.warning_amber_rounded;
      case 'No Face':
        return Icons.face_retouching_off_rounded;
      case 'Normal':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String _statusLabel() {
    if (!isConnected) return 'Disconnected';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Icon(
              _statusIcon(),
              key: ValueKey(status + isConnected.toString()),
              size: 64,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
            child: Text(
              _statusLabel().toUpperCase(),
              key: ValueKey(_statusLabel()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Real-time monitoring active'
                : 'Cannot reach backend server',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
