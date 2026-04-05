import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsPage extends StatelessWidget {
  final Map<String, dynamic> settings;
  final Function(String key, dynamic value) onUpdate;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final postDelay = settings['postDelay'] as int? ?? 3000;
    final autoRetry = settings['autoRetry'] as bool? ?? true;
    final retryCount = settings['retryCount'] as int? ?? 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: AppColors.red, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Configure your PostX experience',
            style: TextStyle(fontSize: 13, color: AppColors.surface400),
          ),
          const SizedBox(height: 20),

          // Posting Behavior
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: AppColors.surface400),
                    const SizedBox(width: 8),
                    const Text(
                      'Posting Behavior',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Post Delay
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delay Between Posts',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Wait time between platforms (ms)',
                            style: TextStyle(fontSize: 11, color: AppColors.surface500),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: postDelay.toString()),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        onSubmitted: (v) => onUpdate('postDelay', int.tryParse(v) ?? 3000),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Auto Retry
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto Retry',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Retry failed posts automatically',
                            style: TextStyle(fontSize: 11, color: AppColors.surface500),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: autoRetry,
                      onChanged: (v) => onUpdate('autoRetry', v),
                      activeTrackColor: AppColors.red,
                    ),
                  ],
                ),

                if (autoRetry) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Retry Attempts',
                              style: TextStyle(fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Maximum retry count',
                              style: TextStyle(fontSize: 11, color: AppColors.surface500),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(text: retryCount.toString()),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          onSubmitted: (v) => onUpdate('retryCount', int.tryParse(v) ?? 2),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.surface400),
                    const SizedBox(width: 8),
                    const Text(
                      'About',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AboutRow(label: 'App Name', value: 'PostX App'),
                _AboutRow(label: 'Version', value: '1.0.0'),
                _AboutRow(label: 'Developer', value: 'xman studio'),
                _AboutRow(label: 'Platform', value: 'Android (Flutter)'),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.surface400)),
          Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
