import 'platform_model.dart';

enum PostStatus { idle, posting, success, error }

class PostContent {
  String text;
  List<String> imagePaths;
  String? videoPath;

  PostContent({
    this.text = '',
    this.imagePaths = const [],
    this.videoPath,
  });

  PostContent copyWith({
    String? text,
    List<String>? imagePaths,
    String? videoPath,
  }) {
    return PostContent(
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPath: videoPath ?? this.videoPath,
    );
  }
}

class PostHistoryEntry {
  final String id;
  final String text;
  final List<String> imagePaths;
  final SocialPlatform platform;
  final PostStatus status;
  final DateTime postedAt;
  final String? error;
  final String? postUrl;

  PostHistoryEntry({
    required this.id,
    required this.text,
    this.imagePaths = const [],
    required this.platform,
    required this.status,
    required this.postedAt,
    this.error,
    this.postUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'imagePaths': imagePaths,
    'platform': platform.name,
    'status': status.name,
    'postedAt': postedAt.toIso8601String(),
    'error': error,
    'postUrl': postUrl,
  };

  factory PostHistoryEntry.fromJson(Map<String, dynamic> json) => PostHistoryEntry(
    id: json['id'],
    text: json['text'],
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    platform: SocialPlatform.values.firstWhere((e) => e.name == json['platform']),
    status: PostStatus.values.firstWhere((e) => e.name == json['status']),
    postedAt: DateTime.parse(json['postedAt']),
    error: json['error'],
    postUrl: json['postUrl'],
  );
}
