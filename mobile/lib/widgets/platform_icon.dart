import 'package:flutter/material.dart';
import '../models/platform_model.dart';

class PlatformIconWidget extends StatelessWidget {
  final SocialPlatform platform;
  final double size;
  final bool colored;

  const PlatformIconWidget({
    super.key,
    required this.platform,
    this.size = 20,
    this.colored = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = getPlatformConfig(platform);
    return Icon(
      config.icon,
      size: size,
      color: colored ? config.color : Colors.grey,
    );
  }
}

class PlatformChip extends StatelessWidget {
  final SocialPlatform platform;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback? onTap;

  const PlatformChip({
    super.key,
    required this.platform,
    this.isSelected = false,
    this.isConnected = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = getPlatformConfig(platform);

    return GestureDetector(
      onTap: isConnected ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? config.color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? config.color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlatformIconWidget(platform: platform, size: 18, colored: isConnected),
            const SizedBox(width: 8),
            Text(
              config.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isConnected ? Colors.white : Colors.grey,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 14, color: config.color),
            ],
            if (!isConnected) ...[
              const SizedBox(width: 6),
              Text(
                'N/A',
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
