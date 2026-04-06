import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_model.dart';
import '../models/post_target.dart';
import '../services/automation_service.dart';
import '../widgets/platform_icon.dart';

class PostingDialog extends StatefulWidget {
  final String text;
  final List<String> imagePaths;
  final Set<SocialPlatform> platforms;
  final Map<SocialPlatform, PostTarget> targets;
  final int delayMs;

  const PostingDialog({
    super.key,
    required this.text,
    required this.imagePaths,
    required this.platforms,
    this.targets = const {},
    this.delayMs = 3000,
  });

  @override
  State<PostingDialog> createState() => _PostingDialogState();
}

class _PostingDialogState extends State<PostingDialog> {
  final Map<SocialPlatform, _PlatformPostState> _states = {};
  bool _done = false;
  HeadlessInAppWebView? _headlessWebView;

  @override
  void initState() {
    super.initState();
    for (final p in widget.platforms) {
      _states[p] = _PlatformPostState(status: PostStatus.idle);
    }
    _startPosting();
  }

  Future<void> _startPosting() async {
    // Create headless webview
    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      initialSettings: InAppWebViewSettings(
        userAgent:
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
    );
    await _headlessWebView!.run();

    final platforms = widget.platforms.toList();

    for (int i = 0; i < platforms.length; i++) {
      if (!mounted) return;

      final platform = platforms[i];
      setState(() {
        _states[platform] = _PlatformPostState(status: PostStatus.posting);
      });

      final result = await AutomationService.postToPlatform(
        platform,
        widget.text,
        widget.imagePaths,
        _headlessWebView,
        target: widget.targets[platform],
      );

      if (!mounted) return;

      setState(() {
        _states[platform] = _PlatformPostState(
          status: result.success ? PostStatus.success : PostStatus.error,
          error: result.error,
          postUrl: result.postUrl,
        );
      });

      // Delay between platforms (skip after last)
      if (i < platforms.length - 1 && widget.delayMs > 0) {
        await Future.delayed(Duration(milliseconds: widget.delayMs));
      }
    }

    // Cleanup
    await _headlessWebView?.dispose();
    _headlessWebView = null;

    if (mounted) {
      setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _headlessWebView?.dispose();
    super.dispose();
  }

  List<PostHistoryEntry> get results {
    return _states.entries.map((e) {
      return PostHistoryEntry(
        id: '${e.value.completedAt.millisecondsSinceEpoch}_${e.key.name}',
        text: widget.text,
        imagePaths: widget.imagePaths,
        platform: e.key,
        status: e.value.status == PostStatus.posting ? PostStatus.error : e.value.status,
        postedAt: e.value.completedAt,
        error: e.value.error,
        postUrl: e.value.postUrl,
      );
    }).toList();
  }

  int get _successCount => _states.values.where((s) => s.status == PostStatus.success).length;
  int get _errorCount => _states.values.where((s) => s.status == PostStatus.error).length;
  int get _completedCount => _successCount + _errorCount;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: AlertDialog(
        backgroundColor: AppColors.surface800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (_done)
              Icon(
                _errorCount == 0 ? Icons.check_circle : Icons.info,
                color: _errorCount == 0 ? AppColors.success : AppColors.warning,
                size: 22,
              )
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
              ),
            const SizedBox(width: 10),
            Text(
              _done ? 'Posting Complete' : 'Posting...',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.platforms.isEmpty ? 0 : _completedCount / widget.platforms.length,
                  backgroundColor: AppColors.surface700,
                  valueColor: const AlwaysStoppedAnimation(AppColors.red),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_completedCount of ${widget.platforms.length} platforms',
                style: TextStyle(fontSize: 11, color: AppColors.surface400),
              ),
              const SizedBox(height: 14),

              // Per-platform status
              ...widget.platforms.map((platform) {
                final state = _states[platform]!;
                final config = getPlatformConfig(platform);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      PlatformIconWidget(platform: platform, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.name,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                            ),
                            if (state.error != null)
                              Text(
                                state.error!,
                                style: TextStyle(fontSize: 10, color: AppColors.error),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      _statusIcon(state.status),
                    ],
                  ),
                );
              }),

              if (_done) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(
                        icon: Icons.check_circle,
                        color: AppColors.success,
                        label: '$_successCount success',
                      ),
                      _StatChip(
                        icon: Icons.error,
                        color: AppColors.error,
                        label: '$_errorCount failed',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_done)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, results),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(PostStatus status) {
    switch (status) {
      case PostStatus.idle:
        return Icon(Icons.circle_outlined, size: 16, color: AppColors.surface500);
      case PostStatus.posting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red),
        );
      case PostStatus.success:
        return Icon(Icons.check_circle, size: 16, color: AppColors.success);
      case PostStatus.error:
        return Icon(Icons.error, size: 16, color: AppColors.error);
    }
  }
}

class _PlatformPostState {
  final PostStatus status;
  final String? error;
  final String? postUrl;
  final DateTime completedAt;

  _PlatformPostState({required this.status, this.error, this.postUrl, DateTime? completedAt})
      : completedAt = completedAt ?? DateTime.now();
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
