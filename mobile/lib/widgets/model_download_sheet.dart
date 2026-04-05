import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';

/// Bottom sheet that shows AI model download progress with WiFi detection.
class ModelDownloadSheet extends StatefulWidget {
  final bool isWifi;
  final VoidCallback onDismiss;
  final VoidCallback onComplete;

  const ModelDownloadSheet({
    super.key,
    required this.isWifi,
    required this.onDismiss,
    required this.onComplete,
  });

  @override
  State<ModelDownloadSheet> createState() => _ModelDownloadSheetState();
}

class _ModelDownloadSheetState extends State<ModelDownloadSheet> {
  _DownloadState _state = _DownloadState.prompt;
  double _progress = 0.0;
  String _statusText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    // Always show prompt first — let user decide
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0.0;
      _error = null;
    });

    final success = await AiService.downloadModel(
      onProgress: (progress, text) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _statusText = text;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _state = _DownloadState.error;
            _error = error;
          });
        }
      },
    );

    if (success && mounted) {
      setState(() => _state = _DownloadState.complete);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) widget.onComplete();
    }
  }

  void _cancel() {
    AiService.cancelDownload();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surface900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.surface700.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surface600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // AI Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.info.withValues(alpha: 0.2),
                  AppColors.red.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _state == _DownloadState.complete
                  ? Icons.check_circle
                  : _state == _DownloadState.error
                      ? Icons.error
                      : Icons.auto_awesome,
              size: 28,
              color: _state == _DownloadState.complete
                  ? AppColors.success
                  : _state == _DownloadState.error
                      ? AppColors.error
                      : AppColors.info,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _getTitle(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            _getDescription(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.surface400, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Progress or action buttons
          if (_state == _DownloadState.downloading) ...[
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.surface800,
                valueColor: AlwaysStoppedAnimation(AppColors.info),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _statusText,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.surface400),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.info),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.surface300,
                  side: BorderSide(color: AppColors.surface600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel Download'),
              ),
            ),
          ] else if (_state == _DownloadState.prompt) ...[
            // WiFi warning + action buttons
            if (!widget.isWifi) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'re not on WiFi. The model is ${AiService.modelSizeLabel} and will use mobile data.',
                        style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Download now button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Download Now (${AiService.modelSizeLabel})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Later button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.surface300,
                  side: BorderSide(color: AppColors.surface600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Download Later'),
              ),
            ),
          ] else if (_state == _DownloadState.complete) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI model ready! You can now use AI-powered post generation.',
                      style: TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_state == _DownloadState.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, size: 18, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error ?? 'Download failed',
                      style: TextStyle(fontSize: 12, color: AppColors.error, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.surface300,
                      side: BorderSide(color: AppColors.surface600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getTitle() => switch (_state) {
    _DownloadState.prompt => 'AI Model Setup',
    _DownloadState.downloading => 'Downloading Gemma 4...',
    _DownloadState.complete => 'AI Ready!',
    _DownloadState.error => 'Download Failed',
  };

  String _getDescription() => switch (_state) {
    _DownloadState.prompt => 'PostX uses Gemma 4 E2B on-device AI for smart post generation, voice commands, image & video analysis.',
    _DownloadState.downloading => 'Downloading AI model to your device. This only needs to happen once.',
    _DownloadState.complete => 'Gemma 4 E2B is installed and ready to use.',
    _DownloadState.error => 'Something went wrong. Please check your connection and try again.',
  };
}

enum _DownloadState { prompt, downloading, complete, error }
