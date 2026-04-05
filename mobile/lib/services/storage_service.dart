import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_model.dart';
import '../models/post_model.dart';

class StorageService {
  static const _accountsKey = 'accounts';
  static const _historyKey = 'history';
  static const _settingsKey = 'settings';

  // ── Accounts ────────────────────────────────────
  static Future<List<PlatformAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_accountsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => PlatformAccount.fromJson(e)).toList();
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
    return list.map((e) => PostHistoryEntry.fromJson(e)).toList();
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
}
