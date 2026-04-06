import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_target.dart';
import '../services/storage_service.dart';
import 'glass_card.dart';

/// Widget to select posting targets per platform (profile, page, group, etc.)
class PostTargetSelector extends StatefulWidget {
  final Set<SocialPlatform> selectedPlatforms;
  final Map<SocialPlatform, PostTarget> selectedTargets;
  final ValueChanged<Map<SocialPlatform, PostTarget>> onTargetsChanged;

  const PostTargetSelector({
    super.key,
    required this.selectedPlatforms,
    required this.selectedTargets,
    required this.onTargetsChanged,
  });

  @override
  State<PostTargetSelector> createState() => _PostTargetSelectorState();
}

class _PostTargetSelectorState extends State<PostTargetSelector> {
  List<PostTarget> _savedTargets = [];

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final targets = await StorageService.loadPostTargets();
    if (mounted) setState(() => _savedTargets = targets);
  }

  @override
  Widget build(BuildContext context) {
    // Only show for platforms that support multiple targets
    final multiTargetPlatforms = widget.selectedPlatforms
        .where((p) => getSupportedTargets(p).length > 1)
        .toList();

    if (multiTargetPlatforms.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, size: 14, color: AppColors.surface400),
              const SizedBox(width: 6),
              Text(
                'POST TARGETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.surface400,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...multiTargetPlatforms.map((platform) => _PlatformTargetRow(
                platform: platform,
                savedTargets: _savedTargets.where((t) => t.platform == platform).toList(),
                selectedTarget: widget.selectedTargets[platform],
                onTargetSelected: (target) {
                  final updated = Map<SocialPlatform, PostTarget>.from(widget.selectedTargets);
                  if (target != null) {
                    updated[platform] = target;
                  } else {
                    updated.remove(platform);
                  }
                  widget.onTargetsChanged(updated);
                },
                onTargetAdded: (target) async {
                  _savedTargets.add(target);
                  await StorageService.savePostTargets(_savedTargets);
                  if (mounted) setState(() {});
                },
                onTargetDeleted: (target) async {
                  _savedTargets.remove(target);
                  await StorageService.savePostTargets(_savedTargets);
                  if (mounted) setState(() {});
                },
              )),
        ],
      ),
    );
  }
}

class _PlatformTargetRow extends StatelessWidget {
  final SocialPlatform platform;
  final List<PostTarget> savedTargets;
  final PostTarget? selectedTarget;
  final ValueChanged<PostTarget?> onTargetSelected;
  final ValueChanged<PostTarget> onTargetAdded;
  final ValueChanged<PostTarget> onTargetDeleted;

  const _PlatformTargetRow({
    required this.platform,
    required this.savedTargets,
    required this.selectedTarget,
    required this.onTargetSelected,
    required this.onTargetAdded,
    required this.onTargetDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final config = getPlatformConfig(platform);
    final supportedTypes = getSupportedTargets(platform);

    // Build all available options: default profile + saved targets
    final allOptions = <PostTarget>[];
    if (supportedTypes.contains(PostTargetType.profile)) {
      allOptions.add(PostTarget(
        platform: platform,
        type: PostTargetType.profile,
        name: 'My Profile',
      ));
    }
    allOptions.addAll(savedTargets);

    // Auto-select profile if nothing selected
    final currentSelection = selectedTarget ?? (allOptions.isNotEmpty ? allOptions.first : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform name
          Row(
            children: [
              Icon(config.icon, size: 14, color: config.color),
              const SizedBox(width: 6),
              Text(
                config.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const Spacer(),
              // Add target button
              GestureDetector(
                onTap: () => _showAddTargetDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AppColors.info),
                    const SizedBox(width: 2),
                    Text(
                      'Add',
                      style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Target chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allOptions.map((target) {
              final isSelected = currentSelection == target;
              return GestureDetector(
                onTap: () => onTargetSelected(target),
                onLongPress: target.type != PostTargetType.profile
                    ? () => _confirmDelete(context, target)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? config.color.withValues(alpha: 0.2)
                        : AppColors.surface800,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? config.color.withValues(alpha: 0.5)
                          : AppColors.surface700,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _targetIcon(target.type),
                        size: 12,
                        color: isSelected ? config.color : AppColors.surface400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        target.displayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : AppColors.surface300,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _targetIcon(PostTargetType type) => switch (type) {
    PostTargetType.profile => Icons.person,
    PostTargetType.page => Icons.flag,
    PostTargetType.group => Icons.group,
    PostTargetType.channel => Icons.campaign,
  };

  void _showAddTargetDialog(BuildContext context) {
    final supportedTypes = getSupportedTargets(platform)
        .where((t) => t != PostTargetType.profile)
        .toList();

    if (supportedTypes.isEmpty) return;

    PostTargetType selectedType = supportedTypes.first;
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface800,
          title: Text('Add ${getPlatformConfig(platform).name} Target'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type selector
              DropdownButtonFormField<PostTargetType>(
                initialValue: selectedType,
                dropdownColor: AppColors.surface700,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: supportedTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'e.g. My Business Page',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: InputDecoration(
                  labelText: 'ID or URL slug',
                  hintText: _idHint(selectedType),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                idController.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                final target = PostTarget(
                  platform: platform,
                  type: selectedType,
                  id: idController.text.trim(),
                  name: nameController.text.trim(),
                );
                onTargetAdded(target);
                onTargetSelected(target);
                nameController.dispose();
                idController.dispose();
                Navigator.pop(ctx);
              },
              child: Text('Add', style: TextStyle(color: AppColors.info)),
            ),
          ],
        ),
      ),
    );
  }

  String _idHint(PostTargetType type) => switch (type) {
    PostTargetType.page => 'e.g. mybusinesspage',
    PostTargetType.group => 'e.g. group ID or name',
    PostTargetType.channel => 'e.g. @mychannel',
    PostTargetType.profile => '',
  };

  void _confirmDelete(BuildContext context, PostTarget target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Delete Target'),
        content: Text('Remove "${target.displayLabel}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onTargetDeleted(target);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
