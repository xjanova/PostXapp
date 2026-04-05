import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class UpdateService {
  static const String _owner = 'xjanova';
  static const String _repo = 'PostXapp';
  static const String _currentVersion = '1.1.1';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final tagName = (data['tag_name'] as String).replaceFirst('v', '');

      if (_isNewerVersion(tagName, _currentVersion)) {
        // Find APK asset
        final assets = data['assets'] as List;
        final apkAsset = assets.firstWhere(
          (a) => (a['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        return UpdateInfo(
          version: tagName,
          downloadUrl: apkAsset?['browser_download_url'],
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
    final remoteParts = remote.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

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

  Future<void> _download() async {
    if (widget.info.downloadUrl == null) return;

    setState(() => _downloading = true);

    final path = await UpdateService.downloadApk(
      widget.info.downloadUrl!,
      (p) { if (mounted) setState(() => _progress = p); },
    );

    if (path != null && mounted) {
      // Install APK via open_filex (handles FileProvider/content URI)
      await OpenFilex.open(path, type: 'application/vnd.android.package-archive');

      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      setState(() => _downloading = false);
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
      content: Column(
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
        ],
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
                : const Text('Download & Install'),
          ),
      ],
    );
  }
}
