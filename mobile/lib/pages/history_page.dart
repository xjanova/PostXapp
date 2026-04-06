import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/post_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';

class HistoryPage extends StatefulWidget {
  final List<PostHistoryEntry> history;
  final VoidCallback onClearHistory;

  const HistoryPage({
    super.key,
    required this.history,
    required this.onClearHistory,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _filter = 'all'; // all, success, error

  List<PostHistoryEntry> get _filtered {
    if (_filter == 'success') {
      return widget.history.where((h) => h.status == PostStatus.success).toList();
    }
    if (_filter == 'error') {
      return widget.history.where((h) => h.status == PostStatus.error).toList();
    }
    return widget.history;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: AppColors.red, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  if (widget.history.isNotEmpty)
                    GestureDetector(
                      onTap: widget.onClearHistory,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.error)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface800.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _FilterTab(
                      label: 'All (${widget.history.length})',
                      isActive: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    _FilterTab(
                      label: 'Success (${widget.history.where((h) => h.status == PostStatus.success).length})',
                      isActive: _filter == 'success',
                      onTap: () => setState(() => _filter = 'success'),
                    ),
                    _FilterTab(
                      label: 'Failed (${widget.history.where((h) => h.status == PostStatus.error).length})',
                      isActive: _filter == 'error',
                      onTap: () => setState(() => _filter = 'error'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surface800,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history, size: 24, color: AppColors.surface500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.history.isEmpty ? 'No posts yet' : 'No matching posts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.surface300),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your posting history will appear here',
                        style: TextStyle(fontSize: 12, color: AppColors.surface500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final entry = _filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlatformIconWidget(platform: entry.platform, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.text.length > 100
                                        ? '${entry.text.substring(0, 100)}...'
                                        : entry.text,
                                    style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(entry.postedAt),
                                    style: TextStyle(fontSize: 10, color: AppColors.surface500),
                                  ),
                                  if (entry.error != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.error!,
                                      style: TextStyle(fontSize: 11, color: AppColors.error),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              entry.status == PostStatus.success
                                  ? Icons.check_circle
                                  : Icons.error,
                              size: 16,
                              color: entry.status == PostStatus.success
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface700 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.surface400,
            ),
          ),
        ),
      ),
    );
  }
}
