import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_model.dart';

/// Soft rate limiter to help users stay well below per-platform daily and
/// hourly anti-spam thresholds.
///
/// Each platform has BOTH a daily cap and an hourly cap. Both are
/// intentionally conservative — the goal is to prevent the user from
/// accidentally bursting into the "automation/spam" zone, not to max out
/// what each network technically allows.
///
/// Limits are stored as a rolling window of post timestamps in
/// SharedPreferences. Timestamps older than 7 days are pruned each read.
class PostingLimits {
  static const String _prefix = 'posting_limits_';

  /// Conservative daily caps (posts per 24h rolling window).
  /// Well below the soft-ban thresholds real users have reported.
  static const Map<SocialPlatform, int> _dailyLimit = {
    SocialPlatform.facebook:  20,
    SocialPlatform.twitter:   20,
    SocialPlatform.linkedin:  10,
    SocialPlatform.threads:   20,
    SocialPlatform.bluesky:   40,
    SocialPlatform.telegram: 100,
    SocialPlatform.instagram:  8,
    SocialPlatform.tiktok:     5,
    SocialPlatform.pinterest: 15,
    SocialPlatform.youtube:    5,
  };

  /// Conservative hourly caps (posts per 1h rolling window).
  static const Map<SocialPlatform, int> _hourlyLimit = {
    SocialPlatform.facebook:   5,
    SocialPlatform.twitter:    5,
    SocialPlatform.linkedin:   3,
    SocialPlatform.threads:    5,
    SocialPlatform.bluesky:   10,
    SocialPlatform.telegram:  30,
    SocialPlatform.instagram:  3,
    SocialPlatform.tiktok:     2,
    SocialPlatform.pinterest:  5,
    SocialPlatform.youtube:    2,
  };

  /// Returns `null` if the user can post right now, or a short error
  /// message if a rate limit would be exceeded.
  static Future<String?> canPost(SocialPlatform platform) async {
    final timestamps = await _loadTimestamps(platform);
    final now = DateTime.now().millisecondsSinceEpoch;

    final oneHourAgo = now - 60 * 60 * 1000;
    final oneDayAgo = now - 24 * 60 * 60 * 1000;

    final hourCount = timestamps.where((t) => t >= oneHourAgo).length;
    final dayCount = timestamps.where((t) => t >= oneDayAgo).length;

    final hourlyCap = _hourlyLimit[platform] ?? 5;
    final dailyCap = _dailyLimit[platform] ?? 20;

    if (hourCount >= hourlyCap) {
      return 'Hourly limit reached ($hourCount/$hourlyCap). Try again in about an hour to stay safe.';
    }
    if (dayCount >= dailyCap) {
      return 'Daily limit reached ($dayCount/$dailyCap). Wait until tomorrow to avoid rate-limit flags.';
    }
    return null;
  }

  /// Record a successful post. Only call AFTER the platform confirmed
  /// success — we never want to count a failed attempt against the user.
  static Future<void> recordPost(SocialPlatform platform) async {
    final timestamps = await _loadTimestamps(platform);
    timestamps.add(DateTime.now().millisecondsSinceEpoch);

    // Prune anything older than 7 days to keep the list small.
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - 7 * 24 * 60 * 60 * 1000;
    timestamps.removeWhere((t) => t < cutoff);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${platform.name}', jsonEncode(timestamps));
  }

  /// Returns `(hourCount, hourLimit, dayCount, dayLimit)` — useful for
  /// showing the user what's left before the next safe window.
  static Future<({int hourCount, int hourLimit, int dayCount, int dayLimit})>
      getCurrentCounts(SocialPlatform platform) async {
    final timestamps = await _loadTimestamps(platform);
    final now = DateTime.now().millisecondsSinceEpoch;

    final oneHourAgo = now - 60 * 60 * 1000;
    final oneDayAgo = now - 24 * 60 * 60 * 1000;

    return (
      hourCount: timestamps.where((t) => t >= oneHourAgo).length,
      hourLimit: _hourlyLimit[platform] ?? 5,
      dayCount: timestamps.where((t) => t >= oneDayAgo).length,
      dayLimit: _dailyLimit[platform] ?? 20,
    );
  }

  /// Reset counters for a platform (used on account disconnect, or
  /// manually from Settings for debugging).
  static Future<void> reset(SocialPlatform platform) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix${platform.name}');
  }

  static Future<List<int>> _loadTimestamps(SocialPlatform platform) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix${platform.name}');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }
}
