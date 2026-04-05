import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';

class AccountsPage extends StatelessWidget {
  final List<PlatformAccount> accounts;
  final Function(SocialPlatform) onLogin;
  final Function(SocialPlatform) onLogout;

  const AccountsPage({
    super.key,
    required this.accounts,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final connected = accounts.where((a) => a.isConnected).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shield, color: AppColors.red, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Accounts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Login via embedded browser. Cookies stored locally.',
            style: TextStyle(fontSize: 13, color: AppColors.surface400),
          ),
          const SizedBox(height: 16),

          // Progress Bar
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.public, size: 16, color: AppColors.surface400),
                const SizedBox(width: 8),
                Text(
                  '$connected',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  ' of ${allPlatforms.length} connected',
                  style: TextStyle(fontSize: 13, color: AppColors.surface300),
                ),
                const Spacer(),
                SizedBox(
                  width: 100,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: allPlatforms.isEmpty ? 0 : connected / allPlatforms.length,
                      backgroundColor: AppColors.surface800,
                      valueColor: const AlwaysStoppedAnimation(AppColors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Platform Cards
          ...allPlatforms.asMap().entries.map((entry) {
            final platform = entry.value;
            final account = accounts
                .where((a) => a.platformId == platform.id)
                .firstOrNull;
            final isConnected = account?.isConnected ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                borderColor: isConnected
                    ? platform.color.withValues(alpha: 0.3)
                    : null,
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: platform.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: PlatformIconWidget(
                          platform: platform.id,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            platform.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isConnected)
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 10, color: AppColors.success),
                                const SizedBox(width: 4),
                                Text(
                                  account!.displayName.isNotEmpty
                                      ? account.displayName
                                      : account.username,
                                  style: TextStyle(fontSize: 11, color: AppColors.surface400),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Icon(Icons.cancel, size: 10, color: AppColors.surface500),
                                const SizedBox(width: 4),
                                Text(
                                  'Not connected',
                                  style: TextStyle(fontSize: 11, color: AppColors.surface500),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Action button
                    if (isConnected)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconBtn(
                            icon: Icons.refresh,
                            color: AppColors.surface400,
                            onTap: () => onLogin(platform.id),
                          ),
                          const SizedBox(width: 4),
                          _IconBtn(
                            icon: Icons.logout,
                            color: AppColors.error,
                            onTap: () => onLogout(platform.id),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: () => onLogin(platform.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login, size: 14, color: AppColors.red),
                              const SizedBox(width: 4),
                              Text(
                                'Connect',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Security Notice
          GlassCard(
            borderColor: AppColors.warning.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield, size: 16, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Notice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Login sessions are stored locally on your device only. '
                        'Credentials are never sent to third-party servers.',
                        style: TextStyle(fontSize: 11, color: AppColors.surface400, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// WebView Login Page
class WebViewLoginPage extends StatefulWidget {
  final PlatformConfig platform;

  const WebViewLoginPage({super.key, required this.platform});

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface950,
      appBar: AppBar(
        title: Text(
          'Login to ${widget.platform.name}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Done',
              style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppColors.surface800,
              valueColor: const AlwaysStoppedAnimation(AppColors.red),
              minHeight: 2,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.platform.loginUrl)),
              initialSettings: InAppWebViewSettings(
                userAgent:
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
              ),
              onProgressChanged: (_, progress) {
                setState(() => _progress = progress / 100);
              },
            ),
          ),
        ],
      ),
    );
  }
}
