import 'dart:convert';
import 'dart:math';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Human-like behavior helpers to reduce bot-detection / ban risk.
///
/// Social platforms profile sessions aggressively. A purely deterministic
/// "fill → click → done" flow looks like a bot within seconds. This helper
/// simulates the small timing and interaction patterns a real human has:
///
///   • Randomized delays ("reading the page", "moving the mouse", "typing")
///   • Chunked typing with natural pauses, dispatched via execCommand
///     so React/Draft.js/ProseMirror/Quill see the change
///   • Mouse-hover + mousedown/mouseup before click, with real
///     getBoundingClientRect() coordinates
///   • Random-interval scrolling to look like "skimming the feed"
///   • A rotating pool of modern mobile Chrome user agents
///
/// NOTE: All methods are safe on failure — they simply fall back to a
/// no-op or return false, so callers can choose to keep going.
class HumanBehavior {
  static final Random _random = Random();

  /// Rotating pool of recent Chrome mobile UAs. Chosen fresh per posting
  /// session, NOT per post, to avoid looking like a different device with
  /// every tweet.
  static const List<String> _userAgents = [
    'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.122 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-A536B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.78 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; SM-S928U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36',
  ];

  /// Pick a random user-agent string. Callers should cache this for the
  /// entire posting session.
  static String randomUserAgent() {
    return _userAgents[_random.nextInt(_userAgents.length)];
  }

  /// Sleep for a random duration between [minMs] and [maxMs] (inclusive of
  /// min, exclusive of max).
  static Future<void> delay(int minMs, int maxMs) async {
    if (maxMs <= minMs) {
      await Future.delayed(Duration(milliseconds: minMs));
      return;
    }
    final ms = minMs + _random.nextInt(maxMs - minMs);
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// Simulate "user looking at the page" after navigation.
  static Future<void> readPage() => delay(1500, 4500);

  /// Simulate "user moved mouse to the button" before clicking.
  static Future<void> beforeClick() => delay(300, 1200);

  /// Simulate "user finished typing and is deciding to submit".
  static Future<void> afterType() => delay(600, 1800);

  /// Delay between platforms, with ±30% jitter around the user's
  /// configured base delay. Never shorter than 2 seconds.
  static Future<void> betweenPlatforms(int baseMs) async {
    final lower = max(2000, (baseMs * 0.7).round());
    final upper = max(lower + 500, (baseMs * 1.3).round());
    await delay(lower, upper);
  }

  /// Random stepped scrolling to mimic a user skimming content.
  /// Safe to ignore failures — this is purely cosmetic.
  static Future<void> scrollRandom(InAppWebViewController controller) async {
    try {
      final steps = 2 + _random.nextInt(3); // 2-4 scrolls
      for (int i = 0; i < steps; i++) {
        final distance = 80 + _random.nextInt(320);
        await controller.evaluateJavascript(source: '''
          (function() {
            try {
              window.scrollBy({ top: $distance, left: 0, behavior: 'smooth' });
            } catch(e) {
              window.scrollBy(0, $distance);
            }
          })()
        ''');
        await delay(350, 1100);
      }
    } catch (_) {}
  }

  /// Dispatch mouseover/mouseenter/mousemove on the first matching element
  /// BEFORE we click it. Many platforms (X, LinkedIn) actually check this
  /// to distinguish humans from basic DOM-click bots.
  static Future<void> hoverBeforeClick(
    InAppWebViewController controller,
    List<String> selectors,
  ) async {
    final jsArr = jsonEncode(selectors);
    try {
      await controller.evaluateJavascript(source: '''
        (function() {
          var sels = $jsArr;
          var el = null;
          for (var i = 0; i < sels.length; i++) {
            try { el = document.querySelector(sels[i]); if (el) break; } catch(e) {}
          }
          if (!el) return false;
          try {
            var r = el.getBoundingClientRect();
            var x = r.left + r.width / 2;
            var y = r.top + r.height / 2;
            var opts = { bubbles: true, cancelable: true, clientX: x, clientY: y, view: window };
            el.dispatchEvent(new MouseEvent('mouseover', opts));
            el.dispatchEvent(new MouseEvent('mouseenter', opts));
            el.dispatchEvent(new MouseEvent('mousemove', opts));
          } catch(e) {}
          return true;
        })()
      ''');
    } catch (_) {}
    await delay(80, 240);
  }

  /// Human-style click: hover → mousedown → pause → mouseup → click.
  /// Uses real client coordinates so event handlers that check
  /// `e.clientX`/`e.clientY` see a plausible pointer position.
  ///
  /// Returns `true` if an element was found and clicked.
  static Future<bool> humanClick(
    InAppWebViewController controller,
    List<String> selectors,
  ) async {
    await hoverBeforeClick(controller, selectors);
    final jsArr = jsonEncode(selectors);
    try {
      final raw = await controller.evaluateJavascript(source: '''
        (function() {
          var sels = $jsArr;
          var el = null;
          for (var i = 0; i < sels.length; i++) {
            try { el = document.querySelector(sels[i]); if (el) break; } catch(e) {}
          }
          if (!el) return false;
          var target = el.closest('[role="button"], button, a') || el;
          if (target.disabled || target.getAttribute('aria-disabled') === 'true') {
            return false;
          }
          try {
            var r = target.getBoundingClientRect();
            var x = r.left + r.width / 2 + (Math.random() * 6 - 3);
            var y = r.top + r.height / 2 + (Math.random() * 6 - 3);
            var opts = { bubbles: true, cancelable: true, clientX: x, clientY: y, view: window, button: 0 };
            target.dispatchEvent(new MouseEvent('mousedown', opts));
            target.dispatchEvent(new MouseEvent('mouseup', opts));
            target.dispatchEvent(new MouseEvent('click', opts));
          } catch(e) {
            try { target.click(); } catch(e2) { return false; }
          }
          return true;
        })()
      ''');
      return raw == true;
    } catch (_) {
      return false;
    }
  }

  /// Human-style typing into a matched editor.
  ///
  /// Strategy:
  /// 1. Focus the element.
  /// 2. Clear existing content with selectAll + insertText('').
  /// 3. Type in CHUNKS of 2-6 characters, pausing 30-150ms between chunks.
  ///    (Pure char-by-char is too slow for 280-char tweets — this still
  ///    looks human but completes in ~5-10s instead of 30s.)
  /// 4. Occasionally insert a longer "thinking pause" every ~4-7 chunks.
  ///
  /// Uses the same execCommand('insertText') path as the old implementation
  /// so React/Draft.js/Quill/ProseMirror all receive proper input events.
  ///
  /// Returns `true` if the editor was found and filled.
  static Future<bool> humanType(
    InAppWebViewController controller,
    List<String> selectors,
    String text,
  ) async {
    if (text.isEmpty) return true;

    final jsArr = jsonEncode(selectors);

    // Focus + clear
    try {
      final focused = await controller.evaluateJavascript(source: '''
        (function() {
          var sels = $jsArr;
          var el = null;
          for (var i = 0; i < sels.length; i++) {
            try { el = document.querySelector(sels[i]); if (el) break; } catch(e) {}
          }
          if (!el) return false;
          try { el.focus(); } catch(e) {}
          try {
            if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
              var proto = el.tagName === 'TEXTAREA'
                ? window.HTMLTextAreaElement.prototype
                : window.HTMLInputElement.prototype;
              var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
              setter.call(el, '');
              el.dispatchEvent(new Event('input', {bubbles: true}));
            } else {
              document.execCommand('selectAll', false, null);
              document.execCommand('insertText', false, '');
            }
          } catch(e) {}
          return true;
        })()
      ''');
      if (focused != true) return false;
    } catch (_) {
      return false;
    }

    await delay(150, 400);

    // Chunked insert
    int pos = 0;
    int chunksSinceBreath = 0;
    while (pos < text.length) {
      final remaining = text.length - pos;
      int chunkSize = 2 + _random.nextInt(5); // 2..6
      if (chunkSize > remaining) chunkSize = remaining;
      final chunk = text.substring(pos, pos + chunkSize);
      pos += chunkSize;

      final jsChunk = jsonEncode(chunk);
      try {
        await controller.evaluateJavascript(source: '''
          (function() {
            var sels = $jsArr;
            var el = null;
            for (var i = 0; i < sels.length; i++) {
              try { el = document.querySelector(sels[i]); if (el) break; } catch(e) {}
            }
            if (!el) return false;
            try {
              if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
                var proto = el.tagName === 'TEXTAREA'
                  ? window.HTMLTextAreaElement.prototype
                  : window.HTMLInputElement.prototype;
                var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
                setter.call(el, (el.value || '') + $jsChunk);
                el.dispatchEvent(new Event('input', {bubbles: true}));
              } else {
                try { el.focus(); } catch(e) {}
                document.execCommand('insertText', false, $jsChunk);
              }
            } catch(e) {}
            return true;
          })()
        ''');
      } catch (_) {
        // Keep going — a single chunk error shouldn't abort the whole type.
      }

      // Base inter-chunk pause
      await delay(30, 150);

      // Occasional longer "thinking" pause
      chunksSinceBreath++;
      if (chunksSinceBreath >= 4 + _random.nextInt(4)) {
        chunksSinceBreath = 0;
        if (_random.nextDouble() < 0.35) {
          await delay(250, 650);
        }
      }
    }

    // Final change event so frameworks finalize value
    try {
      await controller.evaluateJavascript(source: '''
        (function() {
          var sels = $jsArr;
          for (var i = 0; i < sels.length; i++) {
            try {
              var el = document.querySelector(sels[i]);
              if (el) {
                el.dispatchEvent(new Event('change', {bubbles: true}));
                return true;
              }
            } catch(e) {}
          }
          return false;
        })()
      ''');
    } catch (_) {}

    return true;
  }
}
