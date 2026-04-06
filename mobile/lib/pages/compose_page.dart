import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_target.dart';
import '../models/scheduled_post.dart';
import '../services/scheduler_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';
import '../widgets/post_target_selector.dart';

class ComposePage extends StatefulWidget {
  final List<PlatformAccount> accounts;
  final Future<void> Function(
    String text,
    List<String> images,
    Set<SocialPlatform> platforms,
    Map<SocialPlatform, PostTarget> targets,
  ) onPost;
  final VoidCallback? onScheduleAdded;

  const ComposePage({
    super.key,
    required this.accounts,
    required this.onPost,
    this.onScheduleAdded,
  });

  @override
  State<ComposePage> createState() => ComposePageState();
}

class ComposePageState extends State<ComposePage> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final Set<SocialPlatform> _selectedPlatforms = {};
  final Map<SocialPlatform, PostTarget> _selectedTargets = {};
  final List<String> _images = [];
  bool _isPosting = false;

  List<PlatformAccount> get _connectedAccounts =>
      widget.accounts.where((a) => a.isConnected).toList();

  int get _minMaxLength {
    if (_selectedPlatforms.isEmpty) return 99999;
    return _selectedPlatforms
        .map((p) => getPlatformConfig(p).maxTextLength)
        .reduce((a, b) => a < b ? a : b);
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

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((f) => f.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _handlePost() async {
    if (_isPosting) return;
    if (_textController.text.trim().isEmpty || _selectedPlatforms.isEmpty) return;

    setState(() => _isPosting = true);
    await widget.onPost(
      _textController.text,
      _images,
      Set.of(_selectedPlatforms),
      Map.of(_selectedTargets),
    );
    if (mounted) {
      setState(() => _isPosting = false);
      _reset();
    }
  }

  Future<void> _schedulePost() async {
    if (_textController.text.trim().isEmpty || _selectedPlatforms.isEmpty) return;

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
      text: _textController.text,
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

  void _reset() {
    setState(() {
      _textController.clear();
      _images.clear();
      _selectedPlatforms.clear();
      _selectedTargets.clear();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _textController.text.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.edit_square, color: AppColors.red, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Compose Post',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Create once, publish everywhere',
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
                    'Connect at least one social media account in the Accounts tab to start posting.',
                    style: TextStyle(fontSize: 12, color: AppColors.surface400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Text Input
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'POST CONTENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.surface400,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '$charCount${_minMaxLength < 99999 ? ' / $_minMaxLength' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: charCount > _minMaxLength
                            ? AppColors.error
                            : AppColors.surface500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  minLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.5),
                  decoration: InputDecoration(
                    hintText: "What's on your mind? Write your post here...",
                    hintStyle: TextStyle(color: AppColors.surface500),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.image,
                      label: 'Add Images',
                      onTap: _pickImages,
                    ),
                    const SizedBox(width: 8),
                    Opacity(
                      opacity: 0.5,
                      child: _ActionButton(
                        icon: Icons.videocam,
                        label: 'Coming Soon',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Images preview
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
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 60,
                                height: 60,
                                color: AppColors.surface700,
                                child: const Icon(Icons.image, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => _removeImage(entry.key),
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

          // Platform Selector
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

          // Post Targets (for platforms with multiple targets)
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

          // Action Buttons
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
                            _textController.text.trim().isEmpty)
                        ? null
                        : _handlePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_selectedPlatforms.isEmpty || _textController.text.trim().isEmpty)
                              ? AppColors.surface700
                              : AppColors.red,
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
                                'Post (${_selectedPlatforms.length})',
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
                            _textController.text.trim().isEmpty)
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
          const SizedBox(height: 8),

          if (_textController.text.isNotEmpty || _images.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: _reset,
                child: Text(
                  'Clear & Reset',
                  style: TextStyle(fontSize: 12, color: AppColors.surface500),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface700.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surface600.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.surface300),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.surface200),
            ),
          ],
        ),
      ),
    );
  }
}
