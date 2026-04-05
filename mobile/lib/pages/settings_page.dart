import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(String key, dynamic value) onUpdate;
  final VoidCallback? onDownloadModel;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onUpdate,
    this.onDownloadModel,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _delayController;
  late TextEditingController _retryController;
  String _version = '';

  @override
  void initState() {
    super.initState();
    final postDelay = widget.settings['postDelay'] as int? ?? 3000;
    final retryCount = widget.settings['retryCount'] as int? ?? 2;
    _delayController = TextEditingController(text: postDelay.toString());
    _retryController = TextEditingController(text: retryCount.toString());
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDelay = (widget.settings['postDelay'] as int? ?? 3000).toString();
    final newRetry = (widget.settings['retryCount'] as int? ?? 2).toString();
    if (_delayController.text != newDelay) _delayController.text = newDelay;
    if (_retryController.text != newRetry) _retryController.text = newRetry;
  }

  @override
  void dispose() {
    _delayController.dispose();
    _retryController.dispose();
    super.dispose();
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Delete AI Model'),
        content: const Text('Remove the downloaded AI model? You can re-download it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AiService.deleteModel();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoRetry = widget.settings['autoRetry'] as bool? ?? true;
    final aiReady = AiService.status == AiModelStatus.ready;

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

          // ── AI Model ───────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: AppColors.surface400),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Model (Gemma 4 E2B)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: aiReady
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.surface700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: aiReady
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.surface600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            aiReady ? Icons.check_circle : Icons.cloud_download,
                            size: 14,
                            color: aiReady ? AppColors.success : AppColors.surface400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            aiReady ? 'Downloaded & Ready' : 'Not Downloaded',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: aiReady ? AppColors.success : AppColors.surface400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AiService.modelSizeLabel,
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.surface500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Download / Delete button
                SizedBox(
                  width: double.infinity,
                  child: aiReady
                      ? OutlinedButton.icon(
                          onPressed: _deleteModel,
                          icon: Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                          label: Text('Delete Model', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: widget.onDownloadModel,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Download Model'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  'On-device AI for smart post generation, voice commands, image & video analysis.',
                  style: TextStyle(fontSize: 11, color: AppColors.surface500, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Posting Behavior ───────────────────────
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
                        controller: _delayController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        onSubmitted: (v) => widget.onUpdate('postDelay', int.tryParse(v) ?? 3000),
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
                      onChanged: (v) => widget.onUpdate('autoRetry', v),
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
                          controller: _retryController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          onSubmitted: (v) => widget.onUpdate('retryCount', int.tryParse(v) ?? 2),
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

          // ── About ──────────────────────────────────
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
                _AboutRow(label: 'Version', value: _version.isEmpty ? '...' : _version),
                _AboutRow(label: 'Developer', value: 'xman studio'),
                _AboutRow(label: 'Platform', value: 'Android (Flutter)'),
                _AboutRow(label: 'AI Engine', value: 'Gemma 4 E2B (On-Device)'),
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
