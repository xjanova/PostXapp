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
  static const _modelFileName = 'gemma-4-e2b-it.bin';
  static const _prefModelReady = 'ai_model_ready';
  static const _prefModelPath = 'ai_model_path';

  // Gemma 4 E2B IT quantized model (~1.5GB)
  // This URL should be updated to the actual model hosting location
  static const modelDownloadUrl =
      'https://huggingface.co/google/gemma-4-e2b-it-gguf/resolve/main/gemma-4-e2b-it-Q4_K_M.gguf';
  static const modelSizeBytes = 1610612736; // ~1.5GB approximate

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
  static Future<bool> downloadModel({
    required void Function(double progress, String statusText) onProgress,
    required void Function(String error) onError,
  }) async {
    if (_status == AiModelStatus.downloading) return false;

    _status = AiModelStatus.downloading;
    _downloadProgress = 0.0;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$_modelFileName';
      final tempPath = '$filePath.tmp';
      final file = File(tempPath);

      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(modelDownloadUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? modelSizeBytes;
      var receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        _downloadProgress = receivedBytes / totalBytes;

        final mbReceived = (receivedBytes / 1024 / 1024).toStringAsFixed(0);
        final mbTotal = (totalBytes / 1024 / 1024).toStringAsFixed(0);
        onProgress(_downloadProgress, '$mbReceived / $mbTotal MB');
      }

      await sink.close();
      _httpClient = null;

      // Rename temp to final
      await File(tempPath).rename(filePath);

      // Save path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefModelPath, filePath);
      await prefs.setBool(_prefModelReady, true);

      _modelPath = filePath;
      _status = AiModelStatus.ready;
      _downloadProgress = 1.0;
      return true;
    } catch (e) {
      _status = AiModelStatus.error;
      _downloadProgress = 0.0;
      _httpClient = null;

      // Clean up temp file
      final dir = await getApplicationDocumentsDirectory();
      final tempFile = File('${dir.path}/$_modelFileName.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      onError(msg);
      return false;
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
