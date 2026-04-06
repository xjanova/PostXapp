import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/platform_model.dart';

/// Persists WebView cookies to SharedPreferences so sessions survive
/// app restarts, WebView data clears, and app updates.
class CookieService {
  static const _cookiePrefix = 'cookies_';
  static final CookieManager _manager = CookieManager.instance();

  /// Save all cookies for a platform's domain after login.
  ///
  /// Always writes the prefs record — even if the cookie list is empty —
  /// so that `validateSession` can detect "user went through the connect
  /// flow" for platforms that persist sessions via IndexedDB / localStorage
  /// rather than HTTP cookies (Bluesky, Telegram Web).
  static Future<void> saveCookies(SocialPlatform platform) async {
    final config = getPlatformConfig(platform);
    final url = WebUri(config.baseUrl);

    final cookies = await _manager.getCookies(url: url);

    final list = cookies.map((c) => {
      'name': c.name,
      'value': c.value,
      'domain': c.domain ?? url.host,
      'path': c.path ?? '/',
      'isSecure': c.isSecure ?? true,
      'isHttpOnly': c.isHttpOnly ?? false,
      'expiresDate': c.expiresDate,
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cookiePrefix${platform.name}', jsonEncode(list));
    await prefs.setInt(
      '${_cookiePrefix}${platform.name}_savedAt',
      DateTime.now().millisecondsSinceEpoch,
    );

    // Also save login domain cookies (some platforms use different login domains)
    final loginUri = WebUri(config.loginUrl);
    if (loginUri.host != url.host) {
      final loginCookies = await _manager.getCookies(url: loginUri);
      if (loginCookies.isNotEmpty) {
        final loginList = loginCookies.map((c) => {
          'name': c.name,
          'value': c.value,
          'domain': c.domain ?? loginUri.host,
          'path': c.path ?? '/',
          'isSecure': c.isSecure ?? true,
          'isHttpOnly': c.isHttpOnly ?? false,
          'expiresDate': c.expiresDate,
        }).toList();

        await prefs.setString(
          '${_cookiePrefix}${platform.name}_login',
          jsonEncode(loginList),
        );
      }
    }
  }

  /// Restore saved cookies back into CookieManager.
  /// Call on app startup to restore sessions.
  static Future<void> restoreCookies(SocialPlatform platform) async {
    final prefs = await SharedPreferences.getInstance();
    final config = getPlatformConfig(platform);

    // Restore base domain cookies
    await _restoreFromKey(prefs, '$_cookiePrefix${platform.name}', config.baseUrl);

    // Restore login domain cookies
    await _restoreFromKey(prefs, '${_cookiePrefix}${platform.name}_login', config.loginUrl);
  }

  static Future<void> _restoreFromKey(SharedPreferences prefs, String key, String urlStr) async {
    final data = prefs.getString(key);
    if (data == null) return;

    final List list;
    try {
      list = jsonDecode(data) as List;
    } catch (_) {
      return; // Malformed JSON — skip
    }
    final url = WebUri(urlStr);

    for (final item in list) {
      try {
        final map = item as Map<String, dynamic>;
        await _manager.setCookie(
          url: url,
          name: map['name'],
          value: map['value'],
          domain: map['domain'],
          path: map['path'] ?? '/',
          isSecure: map['isSecure'] ?? true,
          isHttpOnly: map['isHttpOnly'] ?? false,
          expiresDate: map['expiresDate'] != null
              ? (map['expiresDate'] as num).toInt()
              : null,
        );
      } catch (_) {
        // Skip malformed cookie entry
      }
    }
  }

  /// Restore all saved cookies for all connected platforms.
  static Future<void> restoreAllCookies(List<PlatformAccount> accounts) async {
    for (final account in accounts) {
      if (account.isConnected) {
        await restoreCookies(account.platformId);
      }
    }
  }

  /// Delete saved cookies for a platform (on disconnect).
  static Future<void> deleteCookies(SocialPlatform platform) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cookiePrefix${platform.name}');
    await prefs.remove('${_cookiePrefix}${platform.name}_login');
    await prefs.remove('${_cookiePrefix}${platform.name}_savedAt');

    // Also clear from CookieManager
    final config = getPlatformConfig(platform);
    await _manager.deleteCookies(url: WebUri(config.baseUrl));
    if (WebUri(config.loginUrl).host != WebUri(config.baseUrl).host) {
      await _manager.deleteCookies(url: WebUri(config.loginUrl));
    }
  }

  /// Check if a platform session is likely still valid, based on saved
  /// cookies.  Fast (no network).
  ///
  /// For most platforms this checks for the presence of a real auth
  /// cookie. Bluesky and Telegram Web store their session in
  /// IndexedDB/localStorage (not HTTP cookies), so we fall back to
  /// "user went through the connect flow" detected via the _savedAt
  /// timestamp marker.
  static Future<bool> validateSession(SocialPlatform platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_cookiePrefix${platform.name}');
      // No saved cookies = user never completed the connect flow.
      if (data == null) return false;

      // Bluesky and Telegram Web keep their session in IndexedDB/
      // localStorage rather than HTTP cookies. We already know a
      // prefs record exists (checked above), which means the user
      // went through the connect flow — treat them as valid.
      if (platform == SocialPlatform.bluesky ||
          platform == SocialPlatform.telegram) {
        return true;
      }

      final list = jsonDecode(data) as List;
      if (list.isEmpty) return false;

      // Check for a meaningful session cookie (not just tracking).
      final hasSessionCookie = list.any((c) {
        final name = (c['name']?.toString() ?? '').toLowerCase();
        return name.contains('session') ||
            name.contains('token') ||
            name.contains('auth') ||
            name.contains('login') ||
            name.contains('sid') ||
            name.contains('c_user') ||      // Facebook user id
            name == 'xs' ||                 // Facebook session secret
            name == 'fr' ||                 // Facebook fr session
            name.contains('auth_token') ||  // X / Twitter
            name.contains('li_at') ||       // LinkedIn
            name.contains('csrftoken') ||   // Instagram, Threads
            name.contains('ds_user_id') ||  // Instagram, Threads
            name.contains('stel_');         // Telegram
      });

      return hasSessionCookie;
    } catch (_) {
      return false;
    }
  }

  /// Check if saved cookies exist (quick check, no network).
  static Future<bool> hasSavedCookies(SocialPlatform platform) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_cookiePrefix${platform.name}');
  }
}
