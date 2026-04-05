import 'platform_model.dart';

enum PostTargetType {
  profile,
  page,
  group,
  channel,
}

class PostTarget {
  final SocialPlatform platform;
  final PostTargetType type;
  final String id; // user-defined ID or URL slug
  final String name; // display name

  const PostTarget({
    required this.platform,
    required this.type,
    this.id = '',
    this.name = '',
  });

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'type': type.name,
    'id': id,
    'name': name,
  };

  factory PostTarget.fromJson(Map<String, dynamic> json) => PostTarget(
    platform: SocialPlatform.values.where((e) => e.name == json['platform']).firstOrNull
        ?? SocialPlatform.facebook,
    type: PostTargetType.values.where((e) => e.name == json['type']).firstOrNull
        ?? PostTargetType.profile,
    id: json['id'] ?? '',
    name: json['name'] ?? '',
  );

  String get displayLabel {
    if (name.isNotEmpty) return name;
    switch (type) {
      case PostTargetType.profile:
        return 'My Profile';
      case PostTargetType.page:
        return 'Page: $id';
      case PostTargetType.group:
        return 'Group: $id';
      case PostTargetType.channel:
        return 'Channel: $id';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostTarget &&
          platform == other.platform &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => Object.hash(platform, type, id);
}

/// Which target types each platform supports.
List<PostTargetType> getSupportedTargets(SocialPlatform platform) {
  switch (platform) {
    case SocialPlatform.facebook:
      return [PostTargetType.profile, PostTargetType.page, PostTargetType.group];
    case SocialPlatform.linkedin:
      return [PostTargetType.profile, PostTargetType.page];
    case SocialPlatform.telegram:
      return [PostTargetType.channel, PostTargetType.group];
    case SocialPlatform.youtube:
      return [PostTargetType.channel];
    default:
      return [PostTargetType.profile];
  }
}
