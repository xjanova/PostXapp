import 'dart:async';
import '../models/scheduled_post.dart';
import '../models/post_model.dart';
import 'storage_service.dart';

class SchedulerService {
  static Timer? _timer;
  static List<ScheduledPost> _scheduledPosts = [];
  static Future<void> Function(ScheduledPost post)? _onPostDue;

  static List<ScheduledPost> get scheduledPosts => List.unmodifiable(_scheduledPosts);

  static List<ScheduledPost> get pendingPosts =>
      _scheduledPosts.where((p) => p.status == ScheduleStatus.pending).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  static List<ScheduledPost> get completedPosts =>
      _scheduledPosts.where((p) => p.status == ScheduleStatus.completed || p.status == ScheduleStatus.failed).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  /// Initialize scheduler: load saved posts and start timer.
  static Future<void> init({
    required Future<void> Function(ScheduledPost post) onPostDue,
  }) async {
    _onPostDue = onPostDue;
    _scheduledPosts = await StorageService.loadScheduledPosts();

    // Recover posts stuck in 'posting' from a previous crash/kill
    bool dirty = false;
    for (final post in _scheduledPosts) {
      if (post.status == ScheduleStatus.posting) {
        post.status = ScheduleStatus.pending;
        dirty = true;
      }
    }
    if (dirty) await _save();

    _startTimer();
  }

  /// Start the periodic check timer (every 30 seconds).
  static void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDuePosts());
  }

  /// Stop the scheduler timer.
  static void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  static bool _isChecking = false;

  /// Check for posts that are due and execute them.
  static Future<void> _checkDuePosts() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final duePosts = _scheduledPosts
          .where((p) => p.isPending && p.isDue)
          .toList();

      for (final post in duePosts) {
        post.status = ScheduleStatus.posting;
        await _save();

        if (_onPostDue != null) {
          await _onPostDue!(post);
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  /// Add a new scheduled post.
  static Future<void> addScheduledPost(ScheduledPost post) async {
    _scheduledPosts.add(post);
    await _save();
  }

  /// Update an existing scheduled post.
  static Future<void> updateScheduledPost(ScheduledPost updated) async {
    final index = _scheduledPosts.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      _scheduledPosts[index] = updated;
      await _save();
    }
  }

  /// Mark a scheduled post as completed with results.
  static Future<void> markCompleted(String id, List<PostHistoryEntry> results) async {
    final post = _scheduledPosts.where((p) => p.id == id).firstOrNull;
    if (post != null) {
      post.status = ScheduleStatus.completed;
      post.results = results;
      await _save();
    }
  }

  /// Mark a scheduled post as failed.
  static Future<void> markFailed(String id, String error) async {
    final post = _scheduledPosts.where((p) => p.id == id).firstOrNull;
    if (post != null) {
      post.status = ScheduleStatus.failed;
      post.error = error;
      await _save();
    }
  }

  /// Revert a post back to pending so the scheduler picks it up on the
  /// next tick. Used when we need to defer (e.g. user is already posting).
  static Future<void> revertToPending(String id) async {
    final post = _scheduledPosts.where((p) => p.id == id).firstOrNull;
    if (post != null) {
      post.status = ScheduleStatus.pending;
      await _save();
    }
  }

  /// Cancel a scheduled post.
  static Future<void> cancelPost(String id) async {
    final post = _scheduledPosts.where((p) => p.id == id).firstOrNull;
    if (post != null) {
      post.status = ScheduleStatus.cancelled;
      await _save();
    }
  }

  /// Delete a scheduled post permanently.
  static Future<void> deletePost(String id) async {
    _scheduledPosts.removeWhere((p) => p.id == id);
    await _save();
  }

  /// Delete all completed/failed/cancelled posts.
  static Future<void> clearCompleted() async {
    _scheduledPosts.removeWhere((p) =>
        p.status == ScheduleStatus.completed ||
        p.status == ScheduleStatus.failed ||
        p.status == ScheduleStatus.cancelled);
    await _save();
  }

  static int _idCounter = 0;

  /// Generate a unique ID for new scheduled posts.
  static String generateId() {
    _idCounter++;
    return 'sched_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  static Future<void> _save() async {
    await StorageService.saveScheduledPosts(_scheduledPosts);
  }
}
