import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scheduled_post.dart';
import '../services/scheduler_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';

class SchedulePage extends StatefulWidget {
  final VoidCallback? onRefresh;

  const SchedulePage({super.key, this.onRefresh});

  @override
  State<SchedulePage> createState() => SchedulePageState();
}

class SchedulePageState extends State<SchedulePage> {
  String _filter = 'pending'; // pending, completed
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _filter == 'pending') setState(() {});
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  List<ScheduledPost> get _filtered {
    if (_filter == 'pending') return SchedulerService.pendingPosts;
    return SchedulerService.completedPosts;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = SchedulerService.pendingPosts.length;
    final completedCount = SchedulerService.completedPosts.length;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.red, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Scheduled',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  if (completedCount > 0)
                    GestureDetector(
                      onTap: _clearCompleted,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text('Clear Done', style: TextStyle(fontSize: 12, color: AppColors.error)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$pendingCount pending, $completedCount done',
                style: TextStyle(fontSize: 13, color: AppColors.surface400),
              ),
              const SizedBox(height: 12),

              // Filter tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface800.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _FilterTab(
                      label: 'Pending ($pendingCount)',
                      isActive: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    _FilterTab(
                      label: 'Completed ($completedCount)',
                      isActive: _filter == 'completed',
                      onTap: () => setState(() => _filter = 'completed'),
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
                        child: Icon(Icons.schedule, size: 24, color: AppColors.surface500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _filter == 'pending' ? 'No scheduled posts' : 'No completed posts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.surface300),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use AI Compose to schedule posts in advance',
                        style: TextStyle(fontSize: 12, color: AppColors.surface500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    return _ScheduledPostCard(
                      post: _filtered[index],
                      onCancel: _filter == 'pending' ? () => _cancelPost(_filtered[index]) : null,
                      onDelete: () => _deletePost(_filtered[index]),
                      onEdit: _filter == 'pending' ? () => _editPost(_filtered[index]) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _cancelPost(ScheduledPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Cancel Scheduled Post'),
        content: const Text('This post will not be published. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Post', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SchedulerService.cancelPost(post.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deletePost(ScheduledPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Delete Post'),
        content: const Text('Permanently delete this scheduled post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SchedulerService.deletePost(post.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editPost(ScheduledPost post) async {
    final date = await showDatePicker(
      context: context,
      initialDate: post.scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      initialTime: TimeOfDay.fromDateTime(post.scheduledAt),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.red),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final newTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (newTime.isBefore(DateTime.now())) {
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
    post.scheduledAt = newTime;
    await SchedulerService.updateScheduledPost(post);
    if (mounted) setState(() {});
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface800,
        title: const Text('Clear Completed'),
        content: const Text('Remove all completed/failed/cancelled posts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SchedulerService.clearCompleted();
      if (mounted) setState(() {});
    }
  }
}

class _ScheduledPostCard extends StatelessWidget {
  final ScheduledPost post;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _ScheduledPostCard({
    required this.post,
    this.onCancel,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + Time
            Row(
              children: [
                _StatusBadge(status: post.status),
                const Spacer(),
                Icon(Icons.schedule, size: 12, color: AppColors.surface500),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(post.scheduledAt),
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.surface400),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Countdown (for pending)
            if (post.isPending) ...[
              _CountdownRow(timeUntil: post.timeUntil),
              const SizedBox(height: 8),
            ],

            // Post text preview
            Text(
              post.text.length > 120 ? '${post.text.substring(0, 120)}...' : post.text,
              style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 10),

            // Platforms
            Wrap(
              spacing: 4,
              children: post.platforms.map((p) {
                return PlatformIconWidget(platform: p, size: 16);
              }).toList(),
            ),

            // Error message
            if (post.error != null) ...[
              const SizedBox(height: 8),
              Text(
                post.error!,
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],

            // Actions
            if (onCancel != null || onDelete != null || onEdit != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit, size: 14, color: AppColors.info),
                      label: Text('Reschedule', style: TextStyle(fontSize: 11, color: AppColors.info)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (onCancel != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: Icon(Icons.cancel_outlined, size: 14, color: AppColors.warning),
                      label: Text('Cancel', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                      label: Text('Delete', style: TextStyle(fontSize: 11, color: AppColors.error)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final ScheduleStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      ScheduleStatus.pending => (AppColors.info, Icons.schedule, 'Pending'),
      ScheduleStatus.posting => (AppColors.warning, Icons.send, 'Posting...'),
      ScheduleStatus.completed => (AppColors.success, Icons.check_circle, 'Done'),
      ScheduleStatus.failed => (AppColors.error, Icons.error, 'Failed'),
      ScheduleStatus.cancelled => (AppColors.surface500, Icons.cancel, 'Cancelled'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatelessWidget {
  final Duration timeUntil;

  const _CountdownRow({required this.timeUntil});

  @override
  Widget build(BuildContext context) {
    String label;
    if (timeUntil.isNegative) {
      label = 'Overdue — will post soon';
    } else if (timeUntil.inDays > 0) {
      label = 'In ${timeUntil.inDays}d ${timeUntil.inHours % 24}h';
    } else if (timeUntil.inHours > 0) {
      label = 'In ${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m';
    } else {
      label = 'In ${timeUntil.inMinutes}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface800,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 12, color: AppColors.surface400),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.surface300),
          ),
        ],
      ),
    );
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
