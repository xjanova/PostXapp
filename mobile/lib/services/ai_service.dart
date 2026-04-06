import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

enum AiModelStatus { notDownloaded, downloading, ready, error }

class AiService {
  static const _channel = MethodChannel('com.postxapp/gemma');
  static const _modelFileName = 'gemma-4-E2B-it.litertlm';
  static const _prefModelReady = 'ai_model_ready';
  static const _prefModelPath = 'ai_model_path';

  // Gemma 4 E2B IT — LiteRT-LM bundle (mixed 2/4/8-bit quant) — ~2.58GB
  // Public, non-gated mirror maintained by Google's litert-community.
  // Runs via com.google.ai.edge.litertlm:litertlm-android on device.
  static const modelDownloadUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  static const modelSizeBytes = 2770053464; // ~2.58GB actual
  static const _minValidSizeBytes = 100 * 1024 * 1024; // 100MB — anything smaller is corrupted

  static AiModelStatus _status = AiModelStatus.notDownloaded;
  static double _downloadProgress = 0.0;
  static bool _isModelLoaded = false;
  static String? _modelPath;
  static http.Client? _httpClient;

  static AiModelStatus get status => _status;
  static double get downloadProgress => _downloadProgress;
  static bool get isModelLoaded => _isModelLoaded;
  static String get modelSizeLabel => '${(modelSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';

  /// Check if model files exist on disk.
  static Future<AiModelStatus> checkModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefModelPath);

    if (path != null && await File(path).exists()) {
      _modelPath = path;
      _status = AiModelStatus.ready;
      return AiModelStatus.ready;
    }

    // Check default location
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_modelFileName');
    if (await file.exists()) {
      _modelPath = file.path;
      _status = AiModelStatus.ready;
      await prefs.setString(_prefModelPath, file.path);
      await prefs.setBool(_prefModelReady, true);
      return AiModelStatus.ready;
    }

    _status = AiModelStatus.notDownloaded;
    return AiModelStatus.notDownloaded;
  }

  /// Check if currently on WiFi.
  static Future<bool> isOnWifi() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.wifi);
  }

  /// Check if any network is available.
  static Future<bool> hasNetwork() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Download the model with progress callback.
  ///
  /// Resumable: if a partial `.tmp` file exists from a previous failed
  /// attempt, the download continues from that byte offset using an
  /// HTTP `Range` header. The temp file is intentionally NOT deleted on
  /// network failures so that retrying picks up where it left off.
  ///
  /// Auto-retries on `ClientException` / `SocketException` /
  /// `TimeoutException` with exponential backoff (1s, 2s, 4s … capped
  /// at 60s) up to [maxAttempts] times. Only HTTP 4xx (except 408/429)
  /// and validation errors fail fast.
  static Future<bool> downloadModel({
    required void Function(double progress, String statusText) onProgress,
    required void Function(String error) onError,
  }) async {
    if (_status == AiModelStatus.downloading) return false;

    _status = AiModelStatus.downloading;
    _downloadProgress = 0.0;

    const maxAttempts = 8;
    var attempt = 0;
    Object? lastError;

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$_modelFileName';
    final tempPath = '$filePath.tmp';

    while (attempt < maxAttempts) {
      attempt++;
      final isCancelled = _httpClient == null && attempt > 1;
      if (isCancelled) {
        // Cancellation requested between retries.
        _status = AiModelStatus.notDownloaded;
        _downloadProgress = 0.0;
        return false;
      }

      try {
        // Resume support: if a previous attempt left a partial file,
        // pick up where it stopped.
        var startBytes = 0;
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          startBytes = await tempFile.length();
          if (startBytes >= modelSizeBytes) {
            // Already-complete temp file from a previous failed rename.
            // Treat as fresh and let the validation step finish it.
            startBytes = 0;
            await tempFile.delete();
          }
        }

        _httpClient = http.Client();
        final request = http.Request('GET', Uri.parse(modelDownloadUrl));
        request.headers['User-Agent'] = 'PostXApp/1.0 (Android; Flutter)';
        request.headers['Accept'] = '*/*';
        if (startBytes > 0) {
          request.headers['Range'] = 'bytes=$startBytes-';
        }

        final response = await _httpClient!.send(request).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw const SocketException(
                'Connection timeout while opening download stream.');
          },
        );

        // 206 = partial content (resume succeeded), 200 = full content
        // (server ignored Range or this was a fresh start).
        final isResume = response.statusCode == 206;
        final isFresh = response.statusCode == 200;

        if (response.statusCode == 416) {
          // Range Not Satisfiable: temp file may be larger than the
          // remote object. Reset and try again from scratch.
          if (await tempFile.exists()) await tempFile.delete();
          _httpClient = null;
          continue;
        }

        if (!isResume && !isFresh) {
          final code = response.statusCode;
          // 408 / 429 / 5xx are transient — let the retry loop handle them.
          if (code == 408 || code == 429 || code >= 500) {
            throw http.ClientException(
              'Server returned HTTP $code (transient). Retrying.',
              Uri.parse(modelDownloadUrl),
            );
          }
          // Anything else (401/403/404 etc.) is fatal.
          final msg = switch (code) {
            401 || 403 =>
              'Access denied. The model server requires authentication.',
            404 => 'Model file not found on server. The download URL may be outdated.',
            _ => 'Download failed: HTTP $code',
          };
          throw Exception(msg);
        }

        // If the server returned 200 even though we asked for a range,
        // it means it doesn't support partial content for this URL.
        // Discard the partial file and start over.
        if (isFresh && startBytes > 0) {
          if (await tempFile.exists()) await tempFile.delete();
          startBytes = 0;
        }

        final contentLength = response.contentLength;
        final totalBytes = contentLength != null
            ? startBytes + contentLength
            : modelSizeBytes;

        var receivedBytes = startBytes;
        final sink = tempFile.openWrite(
          mode: startBytes > 0 ? FileMode.append : FileMode.write,
        );

        try {
          await for (final chunk in response.stream) {
            // Allow cancellation mid-stream.
            if (_httpClient == null) {
              await sink.close();
              // Don't delete the temp file — keep it for resume next time.
              _status = AiModelStatus.notDownloaded;
              _downloadProgress = 0.0;
              return false;
            }
            sink.add(chunk);
            receivedBytes += chunk.length;
            _downloadProgress = receivedBytes / totalBytes;

            final mbReceived = (receivedBytes / 1024 / 1024).toStringAsFixed(0);
            final mbTotal = (totalBytes / 1024 / 1024).toStringAsFixed(0);
            onProgress(_downloadProgress, '$mbReceived / $mbTotal MB');
          }
        } finally {
          await sink.close();
        }
        _httpClient = null;

        // Validate downloaded file size — a few KB usually means HTML
        // error page rather than a real model bundle.
        final downloadedSize = await tempFile.length();
        if (downloadedSize < _minValidSizeBytes) {
          await tempFile.delete();
          throw Exception(
            'Downloaded file is too small '
            '(${(downloadedSize / 1024).toStringAsFixed(0)} KB). '
            'The server may have returned an error page instead of the model.',
          );
        }

        // Success — promote temp to final and persist.
        await tempFile.rename(filePath);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefModelPath, filePath);
        await prefs.setBool(_prefModelReady, true);

        _modelPath = filePath;
        _status = AiModelStatus.ready;
        _downloadProgress = 1.0;
        return true;
      } on http.ClientException catch (e) {
        // Connection dropped mid-stream — most common failure mode on
        // mobile networks. Retry with backoff, keeping the temp file
        // so the next attempt resumes via Range.
        lastError = e;
        _httpClient = null;
        if (attempt >= maxAttempts) break;
        await _backoff(attempt, maxAttempts, onProgress);
      } on SocketException catch (e) {
        // DNS / connect / read timeout. Same retry treatment.
        lastError = e;
        _httpClient = null;
        if (attempt >= maxAttempts) break;
        await _backoff(attempt, maxAttempts, onProgress);
      } on TimeoutException catch (e) {
        lastError = e;
        _httpClient = null;
        if (attempt >= maxAttempts) break;
        await _backoff(attempt, maxAttempts, onProgress);
      } catch (e) {
        // Fatal error — don't retry, but DO keep the temp file so the
        // user can retry manually later (e.g. after fixing access).
        _status = AiModelStatus.error;
        _downloadProgress = 0.0;
        _httpClient = null;
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        onError(msg);
        return false;
      }
    }

    // Out of retries.
    _status = AiModelStatus.error;
    _downloadProgress = 0.0;
    _httpClient = null;
    final err = lastError;
    final friendly = err is SocketException
        ? 'Network error: ${err.message}'
        : err is http.ClientException
            ? 'Connection lost: ${err.message}'
            : err?.toString() ?? 'Unknown error';
    onError(
      'Download failed after $maxAttempts attempts. $friendly\n'
      'Your progress is saved — tap Retry to resume from where it stopped.',
    );
    return false;
  }

  /// Sleep with exponential backoff between download retries, surfacing
  /// the wait to the UI so the user knows we're still alive.
  static Future<void> _backoff(
    int attempt,
    int maxAttempts,
    void Function(double progress, String statusText) onProgress,
  ) async {
    final seconds = (1 << (attempt - 1)).clamp(1, 60);
    for (var remaining = seconds; remaining > 0; remaining--) {
      if (_httpClient == null && attempt > 1) {
        // Honour cancellation during backoff sleep.
        return;
      }
      onProgress(
        _downloadProgress,
        'Connection lost — retrying in ${remaining}s '
        '(attempt $attempt/$maxAttempts)',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Cancel ongoing download.
  static void cancelDownload() {
    _httpClient?.close();
    _httpClient = null;
    _status = AiModelStatus.notDownloaded;
    _downloadProgress = 0.0;
  }

  /// Delete downloaded model to free storage.
  static Future<void> deleteModel() async {
    if (_modelPath != null) {
      final file = File(_modelPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefModelPath);
    await prefs.remove(_prefModelReady);
    _modelPath = null;
    _isModelLoaded = false;
    _status = AiModelStatus.notDownloaded;
  }

  /// Load model into memory for inference (native side).
  static Future<bool> loadModel() async {
    if (_isModelLoaded) return true;
    if (_modelPath == null) return false;

    try {
      final result = await _channel.invokeMethod<bool>('loadModel', {
        'modelPath': _modelPath,
      });
      _isModelLoaded = result ?? false;
      return _isModelLoaded;
    } on PlatformException {
      _isModelLoaded = false;
      return false;
    }
  }

  /// Generate text from a prompt using the on-device model.
  static Future<String> generateText({
    required String prompt,
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async {
    if (!_isModelLoaded) {
      final loaded = await loadModel();
      if (!loaded) {
        return _fallbackGenerate(prompt);
      }
    }

    try {
      final result = await _channel.invokeMethod<String>('generateText', {
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });
      return result ?? '';
    } on PlatformException {
      return _fallbackGenerate(prompt);
    }
  }

  /// Analyze an image and return a description.
  static Future<String> analyzeImage({
    required String imagePath,
    String prompt = 'Describe this image in detail for a social media post.',
  }) async {
    if (!_isModelLoaded) {
      final loaded = await loadModel();
      if (!loaded) {
        return 'AI model not loaded. Please download the model first.';
      }
    }

    try {
      final result = await _channel.invokeMethod<String>('analyzeImage', {
        'imagePath': imagePath,
        'prompt': prompt,
      });
      return result ?? '';
    } on PlatformException {
      return 'Image analysis is not available yet.';
    }
  }

  /// Analyze video frames and return a description.
  static Future<String> analyzeVideo({
    required String videoPath,
    String prompt = 'Describe this video content for a social media post.',
  }) async {
    if (!_isModelLoaded) {
      final loaded = await loadModel();
      if (!loaded) {
        return 'AI model not loaded. Please download the model first.';
      }
    }

    try {
      final result = await _channel.invokeMethod<String>('analyzeVideo', {
        'videoPath': videoPath,
        'prompt': prompt,
      });
      return result ?? '';
    } on PlatformException {
      return 'Video analysis is not available yet.';
    }
  }

  /// Build a structured prompt for post generation.
  static String buildPostPrompt({
    required String topic,
    required String tone,
    required String language,
    required String length,
    String? imageDescription,
    String? videoDescription,
  }) {
    final langLabel = language == 'th' ? 'Thai' : language == 'en' ? 'English' : 'the same language as the topic';
    final lengthGuide = switch (length) {
      'short' => 'Keep it under 280 characters (tweet-length).',
      'medium' => 'Write 2-4 sentences, suitable for Facebook/LinkedIn.',
      'long' => 'Write a detailed post of 3-5 paragraphs, suitable for a blog or article.',
      _ => 'Write a medium-length post.',
    };

    var prompt = '''You are a social media content writer. Generate a post about the following topic.

Topic: $topic
Tone: $tone
Language: Write in $langLabel
Length: $lengthGuide
''';

    if (imageDescription != null) {
      prompt += '\nThe post includes an image: $imageDescription\nReference the image naturally in the post.\n';
    }

    if (videoDescription != null) {
      prompt += '\nThe post includes a video: $videoDescription\nReference the video content in the post.\n';
    }

    prompt += '''
Rules:
- Write ONLY the post text, no explanations or meta-commentary.
- Do NOT include hashtags unless they are commonly used for the topic.
- Make it engaging, authentic, and ready to publish.
- Match the specified tone exactly.

Post:''';

    return prompt;
  }

  /// Fallback text generation when model is not available.
  /// Returns a template the user can customize.
  static String _fallbackGenerate(String prompt) {
    return '[AI model not loaded — please download the Gemma 4 model to enable AI text generation]\n\n'
        'Your prompt: $prompt';
  }
}
