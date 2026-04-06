import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/platform_model.dart';
import '../models/post_target.dart';
import 'cookie_service.dart';
import 'human_behavior.dart';
import 'posting_limits.dart';

class PostResult {
  final bool success;
  final String? postUrl;
  final String? error;

  PostResult({required this.success, this.postUrl, this.error});
}

/// Handles posting text to social platforms via a headless WebView.
///
/// Each platform handler follows the same robust pattern:
///  1. Pre-flight login check via saved session cookies (fast, offline)
///  2. Rate-limit check against PostingLimits (soft cap, per user)
///  3. Navigate and wait for document.readyState = complete
///  4. Poll-wait for composer trigger element (no fixed delays)
///  5. Simulate human behaviour: read-pause → scroll → hover → click
///  6. Human-style chunked typing via HumanBehavior.humanType so
///     React/Draft.js/Quill/ProseMirror pick up the change through
///     their native event pipeline
///  7. Poll-wait for submit button to become enabled
///  8. Human-style click, then VERIFY the post actually went through
///     by checking URL change or element disappearance
///  9. On success, record the post in PostingLimits for rate tracking
///
/// Media upload via WebView is NOT supported because browsers block
/// programmatic assignment to <input type="file">.files for security.
/// Platforms that require media (Instagram, TikTok, Pinterest, YouTube)
/// return an actionable error asking the user to use the native app.
class AutomationService {
  static const int _readyTimeoutMs = 20000;
  static const int _composerTimeoutMs = 12000;
  static const int _submitTimeoutMs = 8000;
  static const int _verifyTimeoutMs = 8000;

  static Future<PostResult> postToPlatform(
    SocialPlatform platform,
    String text,
    List<String> imagePaths,
    HeadlessInAppWebView? webView, {
    PostTarget? target,
  }) async {
    final config = getPlatformConfig(platform);

    // 1. WebView sanity
    if (webView == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }
    final controller = webView.webViewController;
    if (controller == null) {
      return PostResult(success: false, error: 'WebView controller not ready');
    }

    // 2. Pre-flight login check (no network — just looks at saved cookies)
    final hasSession = await CookieService.validateSession(platform);
    if (!hasSession) {
      return PostResult(
        success: false,
        error: 'Not logged in. Open Accounts → Connect ${config.name}.',
      );
    }

    // 3. Rate-limit pre-check — keeps the user below anti-spam thresholds.
    final rateMsg = await PostingLimits.canPost(platform);
    if (rateMsg != null) {
      return PostResult(success: false, error: rateMsg);
    }

    // 4. Truncate to platform limit
    final postText = text.length > config.maxTextLength
        ? '${text.substring(0, config.maxTextLength - 3)}...'
        : text;

    final hasImages = imagePaths.isNotEmpty;

    // 5. Media requirement
    if (config.requiresImage && !hasImages) {
      return PostResult(
        success: false,
        error: '${config.name} requires an image or video.',
      );
    }

    try {
      PostResult result;
      switch (platform) {
        case SocialPlatform.facebook:
          result = await _postToFacebook(controller, postText, hasImages);
          break;
        case SocialPlatform.twitter:
          result = await _postToTwitter(controller, postText, hasImages);
          break;
        case SocialPlatform.linkedin:
          result = await _postToLinkedIn(controller, postText, hasImages);
          break;
        case SocialPlatform.threads:
          result = await _postToThreads(controller, postText, hasImages);
          break;
        case SocialPlatform.bluesky:
          result = await _postToBluesky(controller, postText, hasImages);
          break;
        case SocialPlatform.telegram:
          result = await _postToTelegram(controller, postText, hasImages);
          break;
        case SocialPlatform.instagram:
        case SocialPlatform.tiktok:
        case SocialPlatform.pinterest:
        case SocialPlatform.youtube:
          return PostResult(
            success: false,
            error:
                '${config.name} upload requires the native app (WebView cannot attach media files).',
          );
      }

      // Only record successful posts against the rate limit.
      if (result.success) {
        await PostingLimits.recordPost(platform);
      }
      return result;
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      return PostResult(success: false, error: 'Posting failed: $msg');
    }
  }

  // =====================================================================
  // Helpers
  // =====================================================================

  /// Navigate and wait until the document is fully loaded + SPA has
  /// had time to hydrate. Also performs a human "read the page" pause
  /// and a small random scroll to look natural.
  static Future<void> _navigate(
    InAppWebViewController controller,
    String url,
  ) async {
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    final deadline = DateTime.now().add(Duration(milliseconds: _readyTimeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final state = await controller.evaluateJavascript(
          source: 'document.readyState',
        );
        if (state == 'complete') break;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }
    // Human-style "look at the page" before interacting.
    await HumanBehavior.readPage();
    // Tiny random scroll to look like we're skimming content.
    await HumanBehavior.scrollRandom(controller);
  }

  /// Poll the DOM until ANY of the selectors matches. Returns the matched
  /// index, or -1 if nothing matched in time.
  static Future<int> _waitForAny(
    InAppWebViewController controller,
    List<String> selectors, {
    required int timeoutMs,
  }) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    final jsArr = jsonEncode(selectors);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final raw = await controller.evaluateJavascript(source: '''
          (function() {
            var sels = $jsArr;
            for (var i = 0; i < sels.length; i++) {
              try {
                if (document.querySelector(sels[i])) return i;
              } catch(e) {}
            }
            return -1;
          })()
        ''');
        final idx = raw is num ? raw.toInt() : -1;
        if (idx >= 0) return idx;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return -1;
  }

  /// Returns true if the current URL does NOT contain any of the keywords
  /// (i.e. we are NOT on a login/auth screen).
  static Future<bool> _notOnLogin(
    InAppWebViewController controller,
    List<String> loginKeywords,
  ) async {
    final url = (await controller.getUrl())?.toString().toLowerCase() ?? '';
    for (final k in loginKeywords) {
      if (url.contains(k.toLowerCase())) return false;
    }
    return true;
  }

  /// Wait for a condition, checked repeatedly via JS, to become true.
  /// Used for verifying a post succeeded (editor closed, URL changed, etc.).
  static Future<bool> _waitForCondition(
    InAppWebViewController controller,
    String jsExpression, {
    required int timeoutMs,
  }) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final raw = await controller.evaluateJavascript(
          source: '(function(){ try { return ($jsExpression); } catch(e) { return false; } })()',
        );
        if (raw == true) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  static String _mediaFootnote(bool hasImages) =>
      hasImages ? 'Posted (images/videos require manual upload)' : '';

  // =====================================================================
  // Facebook (m.facebook.com)
  // =====================================================================
  static Future<PostResult> _postToFacebook(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://m.facebook.com/');

    if (!await _notOnLogin(controller, ['login', 'checkpoint', 'recover'])) {
      return PostResult(success: false, error: 'Facebook session expired. Reconnect.');
    }

    // Open composer
    const composerSels = [
      'div[data-sigil="m-feed-pinned-composer"]',
      'div[role="button"][aria-label*="post" i]',
      '[data-sigil="composer-feed"]',
      'textarea[name="xc_message"]',
      'a[href*="/composer/"]',
    ];
    final compIdx = await _waitForAny(
      controller,
      composerSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (compIdx < 0) {
      return PostResult(success: false, error: 'Facebook composer not found');
    }
    // Click it (unless it was already the textarea)
    if (compIdx != 3) {
      await HumanBehavior.beforeClick();
      await HumanBehavior.humanClick(controller, [composerSels[compIdx]]);
      await HumanBehavior.delay(700, 1400);
    }

    // Fill text
    const inputSels = [
      'textarea[name="xc_message"]',
      'textarea[placeholder*="think" i]',
      'div[contenteditable="true"][role="textbox"]',
      'textarea',
    ];
    final inIdx = await _waitForAny(
      controller,
      inputSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (inIdx < 0) {
      return PostResult(success: false, error: 'Facebook input not found');
    }
    if (!await HumanBehavior.humanType(controller, inputSels, text)) {
      return PostResult(success: false, error: 'Failed to fill Facebook composer');
    }
    await HumanBehavior.afterType();

    // Submit
    const submitSels = [
      'button[name="view_post"]:not([disabled])',
      'button[type="submit"][value="Post"]',
      '[data-sigil="submit_composer"]',
      'button[type="submit"]:not([disabled])',
    ];
    final subIdx = await _waitForAny(
      controller,
      submitSels,
      timeoutMs: _submitTimeoutMs,
    );
    if (subIdx < 0) {
      return PostResult(success: false, error: 'Facebook Post button not found');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [submitSels[subIdx]]);

    // Verify: return to feed (URL no longer contains composer) OR composer gone
    final posted = await _waitForCondition(
      controller,
      '''
      (function() {
        var url = window.location.href;
        if (url.indexOf('composer') < 0 && url.indexOf('/create/') < 0) {
          var ta = document.querySelector('textarea[name="xc_message"]');
          return !ta || (ta.value || '').trim().length === 0;
        }
        return false;
      })()
      ''',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://m.facebook.com/' : null,
      error: posted
          ? (hasImages ? _mediaFootnote(true) : null)
          : 'Facebook did not confirm post',
    );
  }

  // =====================================================================
  // X / Twitter (x.com)
  // =====================================================================
  static Future<PostResult> _postToTwitter(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://x.com/compose/post');

    if (!await _notOnLogin(controller, ['i/flow/login', '/login', '/signup', '/i/flow/signup'])) {
      return PostResult(success: false, error: 'X (Twitter) session expired. Reconnect.');
    }

    const editorSels = [
      'div[data-testid="tweetTextarea_0"][contenteditable="true"]',
      'div[data-testid="tweetTextarea_0"]',
      'div[aria-label*="Post text" i]',
      'div[role="textbox"][contenteditable="true"]',
    ];
    final idx = await _waitForAny(
      controller,
      editorSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (idx < 0) {
      return PostResult(success: false, error: 'X composer not found');
    }

    // Hover + focus before typing, like a real user clicking in.
    await HumanBehavior.hoverBeforeClick(controller, editorSels);
    await HumanBehavior.delay(200, 500);

    if (!await HumanBehavior.humanType(controller, editorSels, text)) {
      return PostResult(success: false, error: 'Failed to fill X composer');
    }
    await HumanBehavior.afterType();

    const submitSels = [
      'button[data-testid="tweetButton"]:not([aria-disabled="true"]):not([disabled])',
      'button[data-testid="tweetButtonInline"]:not([aria-disabled="true"]):not([disabled])',
    ];
    final btnIdx = await _waitForAny(
      controller,
      submitSels,
      timeoutMs: _submitTimeoutMs,
    );
    if (btnIdx < 0) {
      return PostResult(
        success: false,
        error: 'X Post button not enabled (text may be empty or over limit)',
      );
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [submitSels[btnIdx]]);

    // Verify: URL leaves /compose/post, or editor cleared
    final posted = await _waitForCondition(
      controller,
      '''
      (function() {
        if (window.location.href.indexOf('/compose/post') < 0) return true;
        var ed = document.querySelector('div[data-testid="tweetTextarea_0"]');
        return !ed || (ed.textContent || '').trim().length === 0;
      })()
      ''',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://x.com' : null,
      error: posted
          ? (hasImages ? _mediaFootnote(true) : null)
          : 'X did not confirm post',
    );
  }

  // =====================================================================
  // LinkedIn
  // =====================================================================
  static Future<PostResult> _postToLinkedIn(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://www.linkedin.com/feed/');

    if (!await _notOnLogin(controller, ['/login', 'authwall', 'checkpoint'])) {
      return PostResult(success: false, error: 'LinkedIn session expired. Reconnect.');
    }

    // Open post composer modal
    const startSels = [
      'button.share-box-feed-entry__trigger',
      'button[aria-label*="Start a post" i]',
      'div.share-box-feed-entry__closed-share-box',
      'button[aria-label*="Create a post" i]',
    ];
    final startIdx = await _waitForAny(
      controller,
      startSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (startIdx < 0) {
      return PostResult(success: false, error: 'LinkedIn "Start a post" not found');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [startSels[startIdx]]);
    await HumanBehavior.delay(900, 1600);

    // Editor (Quill)
    const editorSels = [
      'div.ql-editor[contenteditable="true"]',
      'div[role="textbox"][contenteditable="true"]',
      'div[data-placeholder*="talk about" i]',
    ];
    final edIdx = await _waitForAny(
      controller,
      editorSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (edIdx < 0) {
      return PostResult(success: false, error: 'LinkedIn editor not found');
    }

    await HumanBehavior.hoverBeforeClick(controller, editorSels);
    await HumanBehavior.delay(200, 500);

    if (!await HumanBehavior.humanType(controller, editorSels, text)) {
      return PostResult(success: false, error: 'Failed to fill LinkedIn editor');
    }
    await HumanBehavior.afterType();

    // Submit
    const submitSels = [
      'button.share-actions__primary-action:not([disabled])',
      'button[data-control-name="share.post"]:not([disabled])',
    ];
    final subIdx = await _waitForAny(
      controller,
      submitSels,
      timeoutMs: _submitTimeoutMs,
    );
    bool clicked = false;
    if (subIdx >= 0) {
      await HumanBehavior.beforeClick();
      clicked = await HumanBehavior.humanClick(controller, [submitSels[subIdx]]);
    } else {
      // Fallback: find <button> whose text === "Post"
      try {
        final raw = await controller.evaluateJavascript(source: '''
          (function() {
            var btns = Array.from(document.querySelectorAll('button:not([disabled])'));
            var b = btns.find(function(x) { return x.textContent.trim() === 'Post'; });
            if (b) {
              try {
                var r = b.getBoundingClientRect();
                var x = r.left + r.width / 2;
                var y = r.top + r.height / 2;
                var opts = { bubbles: true, cancelable: true, clientX: x, clientY: y, view: window, button: 0 };
                b.dispatchEvent(new MouseEvent('mouseover', opts));
                b.dispatchEvent(new MouseEvent('mousedown', opts));
                b.dispatchEvent(new MouseEvent('mouseup', opts));
                b.dispatchEvent(new MouseEvent('click', opts));
              } catch(e) { b.click(); }
              return true;
            }
            return false;
          })()
        ''');
        clicked = raw == true;
      } catch (_) {}
    }
    if (!clicked) {
      return PostResult(success: false, error: 'LinkedIn Post button not found');
    }

    // Verify: editor modal closed
    final posted = await _waitForCondition(
      controller,
      'document.querySelector(\'div.ql-editor[contenteditable="true"]\') === null',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://www.linkedin.com' : null,
      error: posted
          ? (hasImages ? _mediaFootnote(true) : null)
          : 'LinkedIn did not confirm post',
    );
  }

  // =====================================================================
  // Threads
  // =====================================================================
  static Future<PostResult> _postToThreads(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://www.threads.net/');

    if (!await _notOnLogin(controller, ['/login', 'challenge'])) {
      return PostResult(success: false, error: 'Threads session expired. Reconnect.');
    }

    const openSels = [
      'div[role="button"][aria-label*="Create" i]',
      'a[href*="/create"]',
      'svg[aria-label*="Create" i]',
      'div[role="button"][aria-label*="post" i]',
    ];
    final oIdx = await _waitForAny(
      controller,
      openSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (oIdx < 0) {
      return PostResult(success: false, error: 'Threads create button not found');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [openSels[oIdx]]);
    await HumanBehavior.delay(900, 1600);

    const editorSels = [
      'div[contenteditable="true"][role="textbox"]',
      'div[contenteditable="true"]',
    ];
    final eIdx = await _waitForAny(
      controller,
      editorSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (eIdx < 0) {
      return PostResult(success: false, error: 'Threads editor not found');
    }

    await HumanBehavior.hoverBeforeClick(controller, editorSels);
    await HumanBehavior.delay(200, 500);

    if (!await HumanBehavior.humanType(controller, editorSels, text)) {
      return PostResult(success: false, error: 'Failed to fill Threads editor');
    }
    await HumanBehavior.afterType();

    // Post button — find by text and enabled state, click with mouse events
    bool clicked = false;
    try {
      final raw = await controller.evaluateJavascript(source: '''
        (function() {
          var btns = Array.from(document.querySelectorAll('div[role="button"], button'));
          var b = btns.find(function(x) {
            var t = (x.textContent || '').trim();
            return (t === 'Post' || t === 'Publish' || t === 'โพสต์') &&
                   x.getAttribute('aria-disabled') !== 'true' &&
                   !x.disabled;
          });
          if (b) {
            try {
              var r = b.getBoundingClientRect();
              var x = r.left + r.width / 2;
              var y = r.top + r.height / 2;
              var opts = { bubbles: true, cancelable: true, clientX: x, clientY: y, view: window, button: 0 };
              b.dispatchEvent(new MouseEvent('mouseover', opts));
              b.dispatchEvent(new MouseEvent('mousedown', opts));
              b.dispatchEvent(new MouseEvent('mouseup', opts));
              b.dispatchEvent(new MouseEvent('click', opts));
            } catch(e) { b.click(); }
            return true;
          }
          return false;
        })()
      ''');
      clicked = raw == true;
    } catch (_) {}
    if (!clicked) {
      return PostResult(success: false, error: 'Threads Post button not available');
    }

    // Verify: editor closed
    final posted = await _waitForCondition(
      controller,
      'document.querySelector(\'div[contenteditable="true"][role="textbox"]\') === null',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://www.threads.net' : null,
      error: posted
          ? (hasImages ? _mediaFootnote(true) : null)
          : 'Threads did not confirm post',
    );
  }

  // =====================================================================
  // Bluesky
  // =====================================================================
  static Future<PostResult> _postToBluesky(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://bsky.app/');

    if (!await _notOnLogin(controller, ['/login', '/signup'])) {
      return PostResult(success: false, error: 'Bluesky session expired. Reconnect.');
    }

    const openSels = [
      'button[aria-label="New post"]',
      '[data-testid="composePromptButton"]',
      '[data-testid="composeFAB"]',
      'button[aria-label*="post" i]',
    ];
    final oIdx = await _waitForAny(
      controller,
      openSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (oIdx < 0) {
      return PostResult(success: false, error: 'Bluesky compose button not found');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [openSels[oIdx]]);
    await HumanBehavior.delay(800, 1500);

    const editorSels = [
      'div.ProseMirror[contenteditable="true"]',
      'div[contenteditable="true"][data-testid="composerTextInput"]',
      'div[contenteditable="true"]',
    ];
    final eIdx = await _waitForAny(
      controller,
      editorSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (eIdx < 0) {
      return PostResult(success: false, error: 'Bluesky editor not found');
    }

    await HumanBehavior.hoverBeforeClick(controller, editorSels);
    await HumanBehavior.delay(200, 500);

    if (!await HumanBehavior.humanType(controller, editorSels, text)) {
      return PostResult(success: false, error: 'Failed to fill Bluesky editor');
    }
    await HumanBehavior.afterType();

    const submitSels = [
      'button[data-testid="composerPublishBtn"]:not([aria-disabled="true"]):not([disabled])',
      'button[aria-label="Publish post"]:not([disabled])',
    ];
    final sIdx = await _waitForAny(
      controller,
      submitSels,
      timeoutMs: _submitTimeoutMs,
    );
    if (sIdx < 0) {
      return PostResult(success: false, error: 'Bluesky Post button not enabled');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [submitSels[sIdx]]);

    final posted = await _waitForCondition(
      controller,
      'document.querySelector(\'div.ProseMirror[contenteditable="true"]\') === null',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://bsky.app' : null,
      error: posted
          ? (hasImages ? _mediaFootnote(true) : null)
          : 'Bluesky did not confirm post',
    );
  }

  // =====================================================================
  // Telegram Web (posts to Saved Messages)
  // =====================================================================
  static Future<PostResult> _postToTelegram(
    InAppWebViewController controller,
    String text,
    bool hasImages,
  ) async {
    await _navigate(controller, 'https://web.telegram.org/k/');

    // Wait for chat list or main UI
    const chatListSels = [
      'ul.chatlist',
      '.chat-list',
      '#column-left',
      'div[data-testid="chat-list"]',
    ];
    final clIdx = await _waitForAny(
      controller,
      chatListSels,
      timeoutMs: 15000,
    );
    if (clIdx < 0) {
      return PostResult(success: false, error: 'Telegram session expired. Reconnect.');
    }

    // Try to open Saved Messages (or stay on current chat if already open)
    try {
      await controller.evaluateJavascript(source: '''
        (function() {
          var items = document.querySelectorAll(
            '.chatlist .chatlist-chat, ul.chatlist li, .ListItem, li.chatlist-chat'
          );
          for (var i = 0; i < items.length; i++) {
            var txt = items[i].textContent || '';
            if (txt.indexOf('Saved Messages') >= 0 ||
                txt.indexOf('ข้อความที่บันทึก') >= 0) {
              items[i].click();
              return;
            }
          }
        })()
      ''');
    } catch (_) {}

    await HumanBehavior.delay(1000, 1800);

    const inputSels = [
      'div.input-message-input[contenteditable="true"]',
      '.input-message-input',
      'div[contenteditable="true"][data-testid="message-input"]',
    ];
    final iIdx = await _waitForAny(
      controller,
      inputSels,
      timeoutMs: _composerTimeoutMs,
    );
    if (iIdx < 0) {
      return PostResult(
        success: false,
        error: 'Telegram input not found. Open a chat first.',
      );
    }

    await HumanBehavior.hoverBeforeClick(controller, inputSels);
    await HumanBehavior.delay(200, 500);

    if (!await HumanBehavior.humanType(controller, inputSels, text)) {
      return PostResult(success: false, error: 'Failed to fill Telegram input');
    }
    await HumanBehavior.afterType();

    const sendSels = [
      'button.btn-send:not([disabled])',
      'button[aria-label="Send" i]:not([disabled])',
      '.btn-send',
    ];
    final sIdx = await _waitForAny(
      controller,
      sendSels,
      timeoutMs: _submitTimeoutMs,
    );
    if (sIdx < 0) {
      return PostResult(success: false, error: 'Telegram Send button not found');
    }
    await HumanBehavior.beforeClick();
    await HumanBehavior.humanClick(controller, [sendSels[sIdx]]);

    // Verify: input cleared
    final posted = await _waitForCondition(
      controller,
      '''
      (function() {
        var el = document.querySelector('.input-message-input');
        if (!el) return false;
        return (el.textContent || '').trim().length === 0;
      })()
      ''',
      timeoutMs: _verifyTimeoutMs,
    );

    return PostResult(
      success: posted,
      postUrl: posted ? 'https://web.telegram.org' : null,
      error: posted
          ? (hasImages
              ? 'Sent to Saved Messages (images require manual upload)'
              : null)
          : 'Telegram did not send message',
    );
  }
}
