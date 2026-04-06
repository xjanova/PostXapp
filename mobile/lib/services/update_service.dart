import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String _owner = 'xjanova';
  static const String _repo = 'PostXapp';

  /// Get current app version from build config.
  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final tagName = (data['tag_name'] as String).replaceFirst('v', '');

      if (_isNewerVersion(tagName, currentVersion)) {
        // Find APK asset
        final assets = data['assets'] as List? ?? [];
        final apkAsset = assets.cast<Map<String, dynamic>>().where(
          (a) => (a['name'] as String).endsWith('.apk'),
        ).firstOrNull;

        return UpdateInfo(
          version: tagName,
          downloadUrl: apkAsset?['browser_download_url'] as String?,
          releaseNotes: data['body'] ?? '',
          publishedAt: data['published_at'] ?? '',
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static bool _isNewerVersion(String remote, String current) {
    // Strip pre-release suffixes (e.g. "1.0.0-beta" → "1.0.0")
    final remoteClean = remote.split('-').first;
    final currentClean = current.split('-').first;
    final remoteParts = remoteClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final currentParts = currentClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  static Future<String?> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/PostXApp-update.apk');
      final sink = file.openWrite();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.close();
      client.close();
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => _UpdateDialog(info: info),
    );
  }
}

class UpdateInfo {
  final String version;
  final String? downloadUrl;
  final String releaseNotes;
  final String publishedAt;

  UpdateInfo({
    required this.version,
    this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    if (widget.info.downloadUrl == null) return;

    setState(() {
      _downloading = true;
      _error = null;
    });

    final path = await UpdateService.downloadApk(
      widget.info.downloadUrl!,
      (p) { if (mounted) setState(() => _progress = p); },
    );

    if (path != null && mounted) {
      try {
        final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
        // OpenFilex returns a ResultType — check if it failed
        if (result.type != ResultType.done && mounted) {
          setState(() {
            _downloading = false;
            _error = 'install_failed';
          });
          return;
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = 'install_failed';
          });
          return;
        }
      }

      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      setState(() {
        _downloading = false;
        _error = 'download_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: AppColors.red, size: 22),
          const SizedBox(width: 8),
          const Text('Update Available', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.info.version} is available',
              style: TextStyle(color: AppColors.surface300, fontSize: 14),
            ),
            if (widget.info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.info.releaseNotes.length > 200
                      ? '${widget.info.releaseNotes.substring(0, 200)}...'
                      : widget.info.releaseNotes,
                  style: TextStyle(fontSize: 12, color: AppColors.surface400, height: 1.4),
                ),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.surface700,
                  valueColor: const AlwaysStoppedAnimation(AppColors.red),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: AppColors.surface400),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          _error == 'install_failed'
                              ? 'Install Failed'
                              : 'Download Failed',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error == 'install_failed'
                          ? 'This is caused by a signing-key change in this '
                            'release. Uninstall the current PostX app, then '
                            'install this new APK. From the next update '
                            'onwards installs will work without uninstalling.'
                          : 'Check your internet connection and try again.',
                      style: TextStyle(fontSize: 11, color: AppColors.surface300, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.pop(context),
          child: Text('Later', style: TextStyle(color: AppColors.surface400)),
        ),
        if (widget.info.downloadUrl != null)
          ElevatedButton(
            onPressed: _downloading ? null : _download,
            child: _downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_error != null ? 'Retry' : 'Download & Install'),
          ),
      ],
    );
  }
}
