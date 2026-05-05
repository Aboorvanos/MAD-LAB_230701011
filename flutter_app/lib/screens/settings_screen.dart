import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Full settings screen with backend URL configuration and alert toggles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Singleton — same instance used everywhere in the app.
  final ApiService _api = ApiService();

  late final TextEditingController _urlController;
  bool _alertsEnabled = true;
  bool _hapticEnabled = true;
  bool _soundEnabled = false;
  bool _saved = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    // Initialise the text field from the CURRENT singleton URL,
    // so whatever was last set is always visible.
    _urlController = TextEditingController(text: _api.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Push the URL to the singleton, then immediately test connectivity
  /// and give the user visual feedback.
  Future<void> _saveSettings() async {
    // 1. Update the shared singleton URL.
    _api.updateBaseUrl(_urlController.text);

    setState(() {
      _saved = true;
      _isTesting = true;
    });

    // 2. Immediately test the new URL.
    final reachable = await _api.checkHealth();

    if (!mounted) return;

    setState(() => _isTesting = false);

    // 3. Show result.
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              reachable
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reachable
                    ? 'Connected to ${_api.baseUrl}'
                    : 'Saved, but backend unreachable at ${_api.baseUrl}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor:
            reachable ? const Color(0xFF7EE787) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded,
                color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Settings'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Backend Configuration ──
              _buildSectionHeader('CONNECTION'),
              const SizedBox(height: 12),
              _buildUrlCard(),
              const SizedBox(height: 28),

              // ── Alerts Configuration ──
              _buildSectionHeader('ALERTS & NOTIFICATIONS'),
              const SizedBox(height: 12),
              _buildToggleTile(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFF58A6FF),
                title: 'Fatigue Alerts',
                subtitle: 'Show alert when fatigue is detected',
                value: _alertsEnabled,
                onChanged: (v) => setState(() => _alertsEnabled = v),
              ),
              const SizedBox(height: 10),
              _buildToggleTile(
                icon: Icons.vibration_rounded,
                iconColor: const Color(0xFFD2A8FF),
                title: 'Haptic Feedback',
                subtitle: 'Vibrate on fatigue alert',
                value: _hapticEnabled,
                onChanged: (v) => setState(() => _hapticEnabled = v),
              ),
              const SizedBox(height: 10),
              _buildToggleTile(
                icon: Icons.volume_up_rounded,
                iconColor: const Color(0xFFFFAA5E),
                title: 'Sound Alerts',
                subtitle: 'Play sound on fatigue detection',
                value: _soundEnabled,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              const SizedBox(height: 28),

              // ── About ──
              _buildSectionHeader('ABOUT'),
              const SizedBox(height: 12),
              _buildAboutCard(),
              const SizedBox(height: 28),

              // ── Save Button ──
              _buildSaveButton(),
              const SizedBox(height: 20),

              // ── Logout Button ──
              _buildLogoutButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Header ──

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.4),
        letterSpacing: 1.5,
      ),
    );
  }

  // ── URL Card ──

  Widget _buildUrlCard() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF58A6FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.link_rounded,
                    color: Color(0xFF58A6FF), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend URL',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Flask API server address',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'http://172.16.232.146:5000',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
              filled: true,
              fillColor: const Color(0xFF0D1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF58A6FF)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              prefixIcon:
                  const Icon(Icons.dns_rounded, size: 18, color: Colors.white38),
            ),
          ),
          const SizedBox(height: 14),

          // Quick-set buttons
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF58A6FF).withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14,
                        color: const Color(0xFF58A6FF).withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF58A6FF).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _quickSetButton(
                    'Wi-Fi (Current)', 'http://172.16.232.146:5000'),
                const SizedBox(height: 6),
                _quickSetButton(
                    'Android Emulator', 'http://10.0.2.2:5000'),
                const SizedBox(height: 6),
                _quickSetButton(
                    'iOS Simulator', 'http://localhost:5000'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickSetButton(String label, String url) {
    return InkWell(
      onTap: () => _urlController.text = url,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              '• $label: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            Text(
              url,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle Tile ──

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF58A6FF),
            activeTrackColor: const Color(0xFF58A6FF).withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  // ── About Card ──

  Widget _buildAboutCard() {
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF58A6FF).withOpacity(0.15),
                      const Color(0xFF7EE787).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.visibility_rounded,
                    color: Color(0xFF58A6FF), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fatigue Monitor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          Text(
            'Real-Time Screen Fatigue Monitoring System with Mobile Dashboard Using Computer Vision and Flutter.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Save Button ──

  Widget _buildSaveButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF58A6FF), Color(0xFF388BFD)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF58A6FF).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isTesting ? null : _saveSettings,
          child: Center(
            child: _isTesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _saved
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded,
                          key: ValueKey(_saved),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Save Settings',
                        style: TextStyle(
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

  // ── Logout Button ──

  Widget _buildLogoutButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          },
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B), size: 20),
                SizedBox(width: 10),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6B6B),
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
}
