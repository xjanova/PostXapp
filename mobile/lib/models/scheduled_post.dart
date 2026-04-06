import 'post_target.dart';
import 'platform_model.dart';
import 'post_model.dart';

enum ScheduleStatus { pending, posting, completed, failed, cancelled }

class ScheduledPost {
  final String id;
  String text;
  List<String> imagePaths;
  Set<SocialPlatform> platforms;
  Map<SocialPlatform, PostTarget> targets;
  DateTime scheduledAt;
  DateTime createdAt;
  ScheduleStatus status;
  String? error;
  List<PostHistoryEntry> results;

  ScheduledPost({
    required this.id,
    required this.text,
    this.imagePaths = const [],
    required this.platforms,
    this.targets = const {},
    required this.scheduledAt,
    DateTime? createdAt,
    this.status = ScheduleStatus.pending,
    this.error,
    this.results = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDue => scheduledAt.isBefore(DateTime.now());
  bool get isPending => status == ScheduleStatus.pending;
  bool get isEditable => status == ScheduleStatus.pending;

  Duration get timeUntil => scheduledAt.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'imagePaths': imagePaths,
    'platforms': platforms.map((p) => p.name).toList(),
    'targets': targets.map((k, v) => MapEntry(k.name, v.toJson())),
    'scheduledAt': scheduledAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'error': error,
    'results': results.map((r) => r.toJson()).toList(),
  };

  factory ScheduledPost.fromJson(Map<String, dynamic> json) {
    final targetsMap = <SocialPlatform, PostTarget>{};
    if (json['targets'] != null) {
      (json['targets'] as Map<String, dynamic>).forEach((key, value) {
        final platform = SocialPlatform.values.where((e) => e.name == key).firstOrNull;
        if (platform != null) {
          targetsMap[platform] = PostTarget.fromJson(value);
        }
      });
    }

    return ScheduledPost(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      platforms: (json['platforms'] as List?)
          ?.map((p) => SocialPlatform.values.where((e) => e.name == p).firstOrNull)
          .whereType<SocialPlatform>()
          .toSet() ?? {},
      targets: targetsMap,
      scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? '') ?? DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      status: ScheduleStatus.values.where(
        (e) => e.name == json['status'],
      ).firstOrNull ?? ScheduleStatus.pending,
      error: json['error'],
      results: (json['results'] as List?)
          ?.map((r) => PostHistoryEntry.fromJson(r))
          .toList() ?? [],
    );
  }
}
