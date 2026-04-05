import 'package:flutter/material.dart';

enum SocialPlatform {
  facebook,
  tiktok,
  twitter,
  instagram,
  linkedin,
  pinterest,
  threads,
  youtube,
  bluesky,
  telegram,
}

class PlatformConfig {
  final SocialPlatform id;
  final String name;
  final IconData icon;
  final Color color;
  final String loginUrl;
  final String baseUrl;
  final int maxTextLength;
  final bool requiresImage;
  final bool supportsVideo;

  const PlatformConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.loginUrl,
    required this.baseUrl,
    required this.maxTextLength,
    this.requiresImage = false,
    this.supportsVideo = false,
  });
}

class PlatformAccount {
  final SocialPlatform platformId;
  String username;
  String displayName;
  bool isConnected;
  DateTime? lastLogin;

  PlatformAccount({
    required this.platformId,
    this.username = '',
    this.displayName = '',
    this.isConnected = false,
    this.lastLogin,
  });

  Map<String, dynamic> toJson() => {
    'platformId': platformId.name,
    'username': username,
    'displayName': displayName,
    'isConnected': isConnected,
    'lastLogin': lastLogin?.toIso8601String(),
  };

  factory PlatformAccount.fromJson(Map<String, dynamic> json) => PlatformAccount(
    platformId: SocialPlatform.values.firstWhere((e) => e.name == json['platformId']),
    username: json['username'] ?? '',
    displayName: json['displayName'] ?? '',
    isConnected: json['isConnected'] ?? false,
    lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
  );
}

// All supported platforms
const List<PlatformConfig> allPlatforms = [
  PlatformConfig(
    id: SocialPlatform.facebook,
    name: 'Facebook',
    icon: Icons.facebook,
    color: Color(0xFF1877F2),
    loginUrl: 'https://m.facebook.com/login/',
    baseUrl: 'https://m.facebook.com',
    maxTextLength: 63206,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.tiktok,
    name: 'TikTok',
    icon: Icons.music_note,
    color: Color(0xFF00F2EA),
    loginUrl: 'https://www.tiktok.com/login',
    baseUrl: 'https://www.tiktok.com',
    maxTextLength: 2200,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.twitter,
    name: 'X (Twitter)',
    icon: Icons.close, // X icon
    color: Color(0xFF9CA3AF),
    loginUrl: 'https://mobile.twitter.com/i/flow/login',
    baseUrl: 'https://mobile.twitter.com',
    maxTextLength: 280,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.instagram,
    name: 'Instagram',
    icon: Icons.camera_alt,
    color: Color(0xFFE4405F),
    loginUrl: 'https://www.instagram.com/accounts/login/',
    baseUrl: 'https://www.instagram.com',
    maxTextLength: 2200,
    requiresImage: true,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.linkedin,
    name: 'LinkedIn',
    icon: Icons.work,
    color: Color(0xFF0A66C2),
    loginUrl: 'https://www.linkedin.com/login',
    baseUrl: 'https://www.linkedin.com',
    maxTextLength: 3000,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.pinterest,
    name: 'Pinterest',
    icon: Icons.push_pin,
    color: Color(0xFFE60023),
    loginUrl: 'https://www.pinterest.com/login/',
    baseUrl: 'https://www.pinterest.com',
    maxTextLength: 500,
    requiresImage: true,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.threads,
    name: 'Threads',
    icon: Icons.alternate_email,
    color: Color(0xFF9CA3AF),
    loginUrl: 'https://www.threads.net/login',
    baseUrl: 'https://www.threads.net',
    maxTextLength: 500,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.youtube,
    name: 'YouTube',
    icon: Icons.play_circle_fill,
    color: Color(0xFFFF0000),
    loginUrl: 'https://accounts.google.com/ServiceLogin',
    baseUrl: 'https://m.youtube.com',
    maxTextLength: 5000,
    supportsVideo: true,
  ),
  PlatformConfig(
    id: SocialPlatform.bluesky,
    name: 'Bluesky',
    icon: Icons.cloud,
    color: Color(0xFF0085FF),
    loginUrl: 'https://bsky.app/login',
    baseUrl: 'https://bsky.app',
    maxTextLength: 300,
  ),
  PlatformConfig(
    id: SocialPlatform.telegram,
    name: 'Telegram',
    icon: Icons.send,
    color: Color(0xFF26A5E4),
    loginUrl: 'https://web.telegram.org/',
    baseUrl: 'https://web.telegram.org',
    maxTextLength: 4096,
    supportsVideo: true,
  ),
];

PlatformConfig getPlatformConfig(SocialPlatform id) {
  return allPlatforms.firstWhere((p) => p.id == id);
}
