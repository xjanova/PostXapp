import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/platform_model.dart';
import '../models/post_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/platform_icon.dart';

class DashboardPage extends StatelessWidget {
  final List<PlatformAccount> accounts;
  final List<PostHistoryEntry> history;
  final VoidCallback onCompose;

  const DashboardPage({
    super.key,
    required this.accounts,
    required this.history,
    required this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    final connected = accounts.where((a) => a.isConnected).length;
    final total = history.length;
    final success = history.where((h) => h.status == PostStatus.success).length;
    final failed = history.where((h) => h.status == PostStatus.error).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview of your posting activity',
                      style: TextStyle(fontSize: 13, color: AppColors.surface400),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onCompose,
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('New Post'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                label: 'PLATFORMS',
                value: '$connected',
                subtitle: 'of ${allPlatforms.length} available',
                icon: Icons.trending_up,
                iconColor: AppColors.info,
              ),
              StatCard(
                label: 'TOTAL POSTS',
                value: '$total',
                subtitle: 'all time',
                icon: Icons.send,
                iconColor: AppColors.red,
              ),
              StatCard(
                label: 'SUCCESSFUL',
                value: '$success',
                subtitle: total > 0 ? '${(success / total * 100).toStringAsFixed(0)}% rate' : '0%',
                icon: Icons.check_circle,
                iconColor: AppColors.success,
              ),
              StatCard(
                label: 'FAILED',
                value: '$failed',
                subtitle: total > 0 ? '${(failed / total * 100).toStringAsFixed(0)}% rate' : '0%',
                icon: Icons.error,
                iconColor: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Platform Status
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart, size: 16, color: AppColors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Platform Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...allPlatforms.map((platform) {
                  final account = accounts
                      .where((a) => a.platformId == platform.id)
                      .firstOrNull;
                  final isConn = account?.isConnected ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        PlatformIconWidget(
                          platform: platform.id,
                          size: 18,
                          colored: isConn,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            platform.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isConn ? Colors.white : AppColors.surface500,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConn ? AppColors.success : AppColors.surface500,
                            boxShadow: isConn
                                ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Post CTA
          GlassCard(
            child: Column(
              children: [
                Icon(Icons.bolt, size: 32, color: AppColors.warning),
                const SizedBox(height: 8),
                const Text(
                  'Quick Post',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create once, publish everywhere',
                  style: TextStyle(fontSize: 12, color: AppColors.surface400),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onCompose,
                    child: const Text('Start Composing'),
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
