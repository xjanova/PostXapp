import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';

class ComposePage extends StatefulWidget {
  final List<PlatformAccount> accounts;
  final Function(String text, List<String> images, Set<SocialPlatform> platforms) onPost;

  const ComposePage({
    super.key,
    required this.accounts,
    required this.onPost,
  });

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final Set<SocialPlatform> _selectedPlatforms = {};
  final List<String> _images = [];
  bool _isPosting = false;
  final Map<SocialPlatform, PostStatus> _results = {};

  List<PlatformAccount> get _connectedAccounts =>
      widget.accounts.where((a) => a.isConnected).toList();

  int get _minMaxLength {
    if (_selectedPlatforms.isEmpty) return 99999;
    return _selectedPlatforms
        .map((p) => getPlatformConfig(p).maxTextLength)
        .reduce((a, b) => a < b ? a : b);
  }

  void _togglePlatform(SocialPlatform platform) {
    setState(() {
      if (_selectedPlatforms.contains(platform)) {
        _selectedPlatforms.remove(platform);
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
    if (_textController.text.trim().isEmpty || _selectedPlatforms.isEmpty) return;

    setState(() {
      _isPosting = true;
      _results.clear();
      for (var p in _selectedPlatforms) {
        _results[p] = PostStatus.posting;
      }
    });

    widget.onPost(_textController.text, _images, _selectedPlatforms);

    // Results will be updated from parent
    setState(() => _isPosting = false);
  }

  void _reset() {
    setState(() {
      _textController.clear();
      _images.clear();
      _selectedPlatforms.clear();
      _results.clear();
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
              Icon(Icons.auto_awesome, color: AppColors.red, size: 22),
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
                    _ActionButton(
                      icon: Icons.videocam,
                      label: 'Add Video',
                      onTap: () {},
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
                            child: Image.asset(
                              entry.value,
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
          const SizedBox(height: 16),

          // Post Button
          SizedBox(
            width: double.infinity,
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
                          'Post to ${_selectedPlatforms.length} Platform${_selectedPlatforms.length != 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
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
