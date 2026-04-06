import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_model.dart';
import '../models/post_model.dart';
import '../models/scheduled_post.dart';
import '../models/post_target.dart';

class StorageService {
  static const _accountsKey = 'accounts';
  static const _historyKey = 'history';
  static const _settingsKey = 'settings';
  static const _scheduledKey = 'scheduled_posts';
  static const _targetsKey = 'post_targets';

  // ── Accounts ────────────────────────────────────
  static Future<List<PlatformAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_accountsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final results = <PlatformAccount>[];
    for (final e in list) {
      try {
        results.add(PlatformAccount.fromJson(e));
      } catch (_) {
        // Skip malformed entries
      }
    }
    return results;
  }

  static Future<void> saveAccounts(List<PlatformAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  // ── History ─────────────────────────────────────
  static Future<List<PostHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final results = <PostHistoryEntry>[];
    for (final e in list) {
      try {
        results.add(PostHistoryEntry.fromJson(e));
      } catch (_) {
        // Skip malformed entries
      }
    }
    return results;
  }

  static Future<void> saveHistory(List<PostHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  // ── Settings ────────────────────────────────────
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_settingsKey);
    if (data == null) {
      return {
        'postDelay': 3000,
        'autoRetry': true,
        'retryCount': 2,
      };
    }
    return jsonDecode(data);
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  // ── Scheduled Posts ────────────────────────────────
  static Future<List<ScheduledPost>> loadScheduledPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_scheduledKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final results = <ScheduledPost>[];
    for (final e in list) {
      try {
        results.add(ScheduledPost.fromJson(e));
      } catch (_) {
        // Skip malformed entries
      }
    }
    return results;
  }

  static Future<void> saveScheduledPosts(List<ScheduledPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduledKey,
      jsonEncode(posts.map((p) => p.toJson()).toList()),
    );
  }

  // ── Post Targets (saved per platform) ─────────────
  static Future<List<PostTarget>> loadPostTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_targetsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    final results = <PostTarget>[];
    for (final e in list) {
      try {
        results.add(PostTarget.fromJson(e));
      } catch (_) {
        // Skip malformed entries
      }
    }
    return results;
  }

  static Future<void> savePostTargets(List<PostTarget> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _targetsKey,
      jsonEncode(targets.map((t) => t.toJson()).toList()),
    );
  }
}
