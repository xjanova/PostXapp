import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_target.dart';
import '../models/scheduled_post.dart';
import '../services/ai_service.dart';
import '../services/scheduler_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';
import '../widgets/post_target_selector.dart';

class AiComposePage extends StatefulWidget {
  final List<PlatformAccount> accounts;
  final Future<void> Function(
    String text,
    List<String> images,
    Set<SocialPlatform> platforms,
    Map<SocialPlatform, PostTarget> targets,
  ) onPost;
  final VoidCallback? onScheduleAdded;

  const AiComposePage({
    super.key,
    required this.accounts,
    required this.onPost,
    this.onScheduleAdded,
  });

  @override
  State<AiComposePage> createState() => _AiComposePageState();
}

class _AiComposePageState extends State<AiComposePage> {
  final _topicController = TextEditingController();
  final _outputController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();

  final Set<SocialPlatform> _selectedPlatforms = {};
  final Map<SocialPlatform, PostTarget> _selectedTargets = {};
  final List<String> _images = [];

  String _tone = 'Professional';
  String _language = 'auto';
  String _length = 'medium';
  bool _isGenerating = false;
  bool _isPosting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _imageDescription;
  String? _videoDescription;

  static const _tones = [
    'Professional',
    'Casual',
    'Humorous',
    'Inspiring',
    'News',
    'Promotional',
    'Educational',
    'Storytelling',
  ];

  static const _languages = {
    'auto': 'Auto',
    'th': 'ไทย',
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
    'ko': '한국어',
  };

  static const _lengths = {
    'short': 'Short (Tweet)',
    'medium': 'Medium (Post)',
    'long': 'Long (Article)',
  };

  List<PlatformAccount> get _connectedAccounts =>
      widget.accounts.where((a) => a.isConnected).toList();

  @override
  void initState() {
    super.initState();
    _topicController.addListener(() => setState(() {}));
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _topicController.dispose();
    _outputController.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _topicController.text = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
            }
          });
        }
      },
      localeId: switch (_language) {
        'th' => 'th_TH',
        'ja' => 'ja_JP',
        'zh' => 'zh_CN',
        'ko' => 'ko_KR',
        'en' => 'en_US',
        _ => null, // auto: use device default
      },
      listenFor: const Duration(seconds: 30),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() {
      _images.addAll(picked.map((f) => f.path));
    });

    // Auto-analyze first image if model is ready
    if (AiService.status == AiModelStatus.ready && _images.isNotEmpty) {
      _analyzeImage(_images.last);
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() => _isGenerating = true);
    final description = await AiService.analyzeVideo(
      videoPath: picked.path,
      prompt: 'Describe this video content briefly for social media context.',
    );

    if (mounted) {
      setState(() {
        _videoDescription = description;
        _isGenerating = false;
      });
    }
  }

  Future<void> _analyzeImage(String path) async {
    final description = await AiService.analyzeImage(
      imagePath: path,
      prompt: 'Describe this image briefly for social media caption context.',
    );
    if (mounted) setState(() => _imageDescription = description);
  }

  Future<void> _generatePost() async {
    if (_topicController.text.trim().isEmpty) return;
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    final prompt = AiService.buildPostPrompt(
      topic: _topicController.text.trim(),
      tone: _tone,
      language: _language,
      length: _length,
      imageDescription: _imageDescription,
      videoDescription: _videoDescription,
    );

    final result = await AiService.generateText(
      prompt: prompt,
      maxTokens: _length == 'long' ? 2048 : _length == 'short' ? 256 : 1024,
    );

    if (mounted) {
      // Don't fill output with fallback placeholder — show error instead
      if (result.startsWith('[AI model not loaded')) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI model not downloaded. Go to Settings to download.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      setState(() {
        _outputController.text = result;
        _isGenerating = false;
      });
    }
  }

  Future<void> _handlePost() async {
    if (_isPosting) return;
    if (_outputController.text.trim().isEmpty || _selectedPlatforms.isEmpty) return;

    setState(() => _isPosting = true);
    await widget.onPost(
      _outputController.text,
      _images,
      Set.of(_selectedPlatforms),
      Map.of(_selectedTargets),
    );
    if (mounted) {
      setState(() {
        _isPosting = false;
        _outputController.clear();
        _topicController.clear();
        _images.clear();
        _selectedPlatforms.clear();
        _selectedTargets.clear();
        _imageDescription = null;
        _videoDescription = null;
      });
    }
  }

  Future<void> _schedulePost() async {
    if (_outputController.text.trim().isEmpty || _selectedPlatforms.isEmpty) return;

    final now = DateTime.now();
    final initialDate = now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.red),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.red),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (scheduledAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scheduled time must be in the future'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final post = ScheduledPost(
      id: SchedulerService.generateId(),
      text: _outputController.text,
      imagePaths: List.from(_images),
      platforms: Set.of(_selectedPlatforms),
      targets: Map.of(_selectedTargets),
      scheduledAt: scheduledAt,
    );

    await SchedulerService.addScheduledPost(post);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled for ${_formatDateTime(scheduledAt)}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    widget.onScheduleAdded?.call();
  }

  void _togglePlatform(SocialPlatform platform) {
    final isConnected = widget.accounts.any((a) => a.platformId == platform && a.isConnected);
    if (!isConnected) return;
    setState(() {
      if (_selectedPlatforms.contains(platform)) {
        _selectedPlatforms.remove(platform);
        _selectedTargets.remove(platform);
      } else {
        _selectedPlatforms.add(platform);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final connected = _connectedAccounts.map((a) => a.platformId).toSet();
      if (connected.every((id) => _selectedPlatforms.contains(id))) {
        _selectedPlatforms.clear();
        _selectedTargets.clear();
      } else {
        _selectedPlatforms.addAll(connected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiReady = AiService.status == AiModelStatus.ready;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.red, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Compose',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              // AI status badge
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
                      size: 12,
                      color: aiReady ? AppColors.success : AppColors.surface400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      aiReady ? 'AI Ready' : 'No Model',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: aiReady ? AppColors.success : AppColors.surface400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'AI-powered post generation with voice & media',
            style: TextStyle(fontSize: 13, color: AppColors.surface400),
          ),
          const SizedBox(height: 20),

          if (_connectedAccounts.isEmpty) ...[
            GlassCard(
              borderColor: AppColors.warning.withValues(alpha: 0.3),
              child: Column(
                children: [
                  Icon(Icons.link_off, size: 28, color: AppColors.warning),
                  const SizedBox(height: 8),
                  Text(
                    'No accounts connected',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect at least one social media account in the Accounts tab before generating posts.',
                    style: TextStyle(fontSize: 12, color: AppColors.surface400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Topic Input ──────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOPIC / IDEA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topicController,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter a topic, idea, or keywords...',
                          hintStyle: TextStyle(color: AppColors.surface500),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Voice button
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppColors.error.withValues(alpha: 0.2)
                              : AppColors.surface700,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isListening
                                ? AppColors.error.withValues(alpha: 0.5)
                                : AppColors.surface600,
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          size: 20,
                          color: _isListening ? AppColors.error : AppColors.surface300,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listening... speak your topic',
                          style: TextStyle(fontSize: 11, color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Options Row ──────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI OPTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                // Tone
                Row(
                  children: [
                    Icon(Icons.mood, size: 14, color: AppColors.surface400),
                    const SizedBox(width: 6),
                    Text('Tone', style: TextStyle(fontSize: 12, color: AppColors.surface300)),
                    const Spacer(),
                    _OptionDropdown<String>(
                      value: _tone,
                      items: _tones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _tone = v ?? _tone),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Language
                Row(
                  children: [
                    Icon(Icons.translate, size: 14, color: AppColors.surface400),
                    const SizedBox(width: 6),
                    Text('Language', style: TextStyle(fontSize: 12, color: AppColors.surface300)),
                    const Spacer(),
                    _OptionDropdown<String>(
                      value: _language,
                      items: _languages.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _language = v ?? _language),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Length
                Row(
                  children: [
                    Icon(Icons.short_text, size: 14, color: AppColors.surface400),
                    const SizedBox(width: 6),
                    Text('Length', style: TextStyle(fontSize: 12, color: AppColors.surface300)),
                    const Spacer(),
                    _OptionDropdown<String>(
                      value: _length,
                      items: _lengths.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _length = v ?? _length),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Media buttons
                Row(
                  children: [
                    _SmallButton(
                      icon: Icons.image,
                      label: 'Image',
                      onTap: _pickImage,
                    ),
                    const SizedBox(width: 8),
                    _SmallButton(
                      icon: Icons.videocam,
                      label: 'Video',
                      onTap: _pickVideo,
                    ),
                    if (_imageDescription != null || _videoDescription != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 10, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              'Media analyzed',
                              style: TextStyle(fontSize: 10, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Image previews
          if (_images.isNotEmpty) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ATTACHED (${_images.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surface400,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _images.asMap().entries.map((entry) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(entry.value),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 56,
                                height: 56,
                                color: AppColors.surface700,
                                child: const Icon(Icons.image, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(entry.key)),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Generate Button ──────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isGenerating || _topicController.text.trim().isEmpty)
                  ? null
                  : _generatePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                disabledBackgroundColor: AppColors.surface700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGenerating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text('Generating...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 8),
                        Text('Generate Post', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Generated Output ─────────────────────
          if (_outputController.text.isNotEmpty) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GENERATED POST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.surface400,
                          letterSpacing: 1,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _generatePost,
                            child: Row(
                              children: [
                                Icon(Icons.refresh, size: 12, color: AppColors.info),
                                const SizedBox(width: 4),
                                Text('Regenerate', style: TextStyle(fontSize: 10, color: AppColors.info)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _outputController,
                    maxLines: 12,
                    minLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'AI generated text will appear here...',
                      hintStyle: TextStyle(color: AppColors.surface500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_outputController.text.length} characters',
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.surface500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Platform Selector ────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'POST TO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.surface400,
                          letterSpacing: 1,
                        ),
                      ),
                      GestureDetector(
                        onTap: _selectAll,
                        child: Text(
                          _connectedAccounts.isNotEmpty &&
                                  _connectedAccounts.every(
                                      (a) => _selectedPlatforms.contains(a.platformId))
                              ? 'Deselect All'
                              : 'Select All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allPlatforms.map((p) {
                      final isConnected = widget.accounts
                          .any((a) => a.platformId == p.id && a.isConnected);
                      return PlatformChip(
                        platform: p.id,
                        isSelected: _selectedPlatforms.contains(p.id),
                        isConnected: isConnected,
                        onTap: () => _togglePlatform(p.id),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Post Targets ─────────────────────────
            PostTargetSelector(
              selectedPlatforms: _selectedPlatforms,
              selectedTargets: _selectedTargets,
              onTargetsChanged: (targets) {
                setState(() {
                  _selectedTargets.clear();
                  _selectedTargets.addAll(targets);
                });
              },
            ),
            if (_selectedPlatforms.any((p) => getSupportedTargets(p).length > 1))
              const SizedBox(height: 12),

            // ── Action Buttons ───────────────────────
            Row(
              children: [
                // Post Now
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isPosting ||
                              _selectedPlatforms.isEmpty ||
                              _outputController.text.trim().isEmpty)
                          ? null
                          : _handlePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        disabledBackgroundColor: AppColors.surface700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isPosting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text('Posting...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Post Now (${_selectedPlatforms.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Schedule
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: (_selectedPlatforms.isEmpty ||
                              _outputController.text.trim().isEmpty)
                          ? null
                          : _schedulePost,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withValues(alpha: 0.5)),
                        disabledForegroundColor: AppColors.surface500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule, size: 16),
                          SizedBox(width: 6),
                          Text('Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _OptionDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _OptionDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface600),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          dropdownColor: AppColors.surface700,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          icon: Icon(Icons.expand_more, size: 16, color: AppColors.surface400),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface700.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surface600.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.surface300),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.surface200)),
          ],
        ),
      ),
    );
  }
}
