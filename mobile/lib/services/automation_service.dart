import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/platform_model.dart';

class PostResult {
  final bool success;
  final String? postUrl;
  final String? error;

  PostResult({required this.success, this.postUrl, this.error});
}

class AutomationService {
  static Future<PostResult> postToPlatform(
    SocialPlatform platform,
    String text,
    List<String> imagePaths,
    HeadlessInAppWebView? webView,
  ) async {
    final config = getPlatformConfig(platform);

    // Truncate text to platform limit
    final postText = text.length > config.maxTextLength
        ? '${text.substring(0, config.maxTextLength - 3)}...'
        : text;

    try {
      switch (platform) {
        case SocialPlatform.facebook:
          return await _postToFacebook(postText, webView);
        case SocialPlatform.twitter:
          return await _postToTwitter(postText, webView);
        case SocialPlatform.linkedin:
          return await _postToLinkedIn(postText, webView);
        case SocialPlatform.threads:
          return await _postToThreads(postText, webView);
        case SocialPlatform.bluesky:
          return await _postToBluesky(postText, webView);
        case SocialPlatform.telegram:
          return await _postToTelegram(postText, webView);
        case SocialPlatform.instagram:
        case SocialPlatform.tiktok:
        case SocialPlatform.pinterest:
        case SocialPlatform.youtube:
          return PostResult(
            success: false,
            error: '${config.name} requires native app or manual interaction for posting.',
          );
      }
    } catch (e) {
      return PostResult(success: false, error: e.toString());
    }
  }

  static Future<PostResult> _postToFacebook(String text, HeadlessInAppWebView? webView) async {
    if (webView == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView.webViewController;
    if (controller == null) {
      return PostResult(success: false, error: 'WebView controller not ready');
    }

    await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://m.facebook.com')));
    await Future.delayed(const Duration(seconds: 3));

    // Check login state
    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.contains('login')) {
      return PostResult(success: false, error: 'Not logged in to Facebook');
    }

    // Click composer
    await controller.evaluateJavascript(source: '''
      (function() {
        var el = document.querySelector('[name="xc_message"]') ||
                 document.querySelector('textarea') ||
                 document.querySelector('[role="textbox"]');
        if (el) { el.focus(); el.click(); el.value = ${_jsEscapeString(text)}; }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    // Submit
    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('button[name="view_post"]') ||
                  document.querySelector('[data-sigil="submit_composer"]') ||
                  document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 3));
    return PostResult(success: true, postUrl: 'https://m.facebook.com');
  }

  static Future<PostResult> _postToTwitter(String text, HeadlessInAppWebView? webView) async {
    if (webView?.webViewController == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView!.webViewController!;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri('https://mobile.twitter.com/compose/tweet')),
    );
    await Future.delayed(const Duration(seconds: 3));

    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.contains('login') || url.contains('flow')) {
      return PostResult(success: false, error: 'Not logged in to X');
    }

    await controller.evaluateJavascript(source: '''
      (function() {
        var box = document.querySelector('[data-testid="tweetTextarea_0"]') ||
                  document.querySelector('[role="textbox"]');
        if (box) { box.focus(); box.textContent = ${_jsEscapeString(text)};
          box.dispatchEvent(new Event('input', {bubbles: true})); }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('[data-testid="tweetButton"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 3));
    return PostResult(success: true, postUrl: 'https://twitter.com');
  }

  static Future<PostResult> _postToLinkedIn(String text, HeadlessInAppWebView? webView) async {
    if (webView?.webViewController == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView!.webViewController!;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://www.linkedin.com/feed/')));
    await Future.delayed(const Duration(seconds: 3));

    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.contains('login') || url.contains('authwall')) {
      return PostResult(success: false, error: 'Not logged in to LinkedIn');
    }

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('.share-box-feed-entry__trigger') ||
                  document.querySelector('button[aria-label*="Start a post"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var editor = document.querySelector('.ql-editor') ||
                     document.querySelector('[role="textbox"][contenteditable="true"]');
        if (editor) { editor.focus(); editor.innerHTML = ${_jsEscapeString(text)}; }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('button.share-actions__primary-action') ||
                  Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === 'Post');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 3));
    return PostResult(success: true, postUrl: 'https://www.linkedin.com');
  }

  static Future<PostResult> _postToThreads(String text, HeadlessInAppWebView? webView) async {
    if (webView?.webViewController == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView!.webViewController!;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://www.threads.net/')));
    await Future.delayed(const Duration(seconds: 3));

    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.contains('login')) {
      return PostResult(success: false, error: 'Not logged in to Threads');
    }

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('[aria-label="Create"]') ||
                  document.querySelector('a[href="/create"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var editor = document.querySelector('[contenteditable="true"]') ||
                     document.querySelector('[role="textbox"]');
        if (editor) { editor.focus(); editor.textContent = ${_jsEscapeString(text)};
          editor.dispatchEvent(new Event('input', {bubbles: true})); }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = Array.from(document.querySelectorAll('div[role="button"], button'))
          .find(b => b.textContent.trim() === 'Post');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 3));
    return PostResult(success: true, postUrl: 'https://www.threads.net');
  }

  static Future<PostResult> _postToBluesky(String text, HeadlessInAppWebView? webView) async {
    if (webView?.webViewController == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView!.webViewController!;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://bsky.app/')));
    await Future.delayed(const Duration(seconds: 3));

    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.contains('login')) {
      return PostResult(success: false, error: 'Not logged in to Bluesky');
    }

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('[data-testid="composePromptButton"]') ||
                  document.querySelector('[aria-label="New post"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var editor = document.querySelector('.ProseMirror') ||
                     document.querySelector('[contenteditable="true"]');
        if (editor) { editor.focus(); editor.textContent = ${_jsEscapeString(text)};
          editor.dispatchEvent(new Event('input', {bubbles: true})); }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('[data-testid="composerPublishBtn"]');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 3));
    return PostResult(success: true, postUrl: 'https://bsky.app');
  }

  static Future<PostResult> _postToTelegram(String text, HeadlessInAppWebView? webView) async {
    if (webView?.webViewController == null) {
      return PostResult(success: false, error: 'WebView not initialized');
    }

    final controller = webView!.webViewController!;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://web.telegram.org/k/')));
    await Future.delayed(const Duration(seconds: 4));

    await controller.evaluateJavascript(source: '''
      (function() {
        var input = document.querySelector('.input-message-input');
        if (input) { input.focus(); input.textContent = ${_jsEscapeString(text)};
          input.dispatchEvent(new Event('input', {bubbles: true})); }
      })()
    ''');

    await Future.delayed(const Duration(seconds: 1));

    await controller.evaluateJavascript(source: '''
      (function() {
        var btn = document.querySelector('.btn-send');
        if (btn) btn.click();
      })()
    ''');

    await Future.delayed(const Duration(seconds: 2));
    return PostResult(success: true, postUrl: 'https://web.telegram.org');
  }

  static String _jsEscapeString(String s) {
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
    return '"$escaped"';
  }
}
