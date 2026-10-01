// post.dart
import 'package:intl/intl.dart';

class Post {
  final int id;
  final String title;
  final String content;
  final int userId;
  final String userName;
  final DateTime createdAt;
  final int commentsCount;
  final String? avatarUrl;
  final int totalLikes;
  final bool isLiked;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.commentsCount = 0,
    this.avatarUrl,
    this.totalLikes = 0,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      userId: json['user_id'],
      userName: json['user_name'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      commentsCount: json['comments_count'] is int
          ? json['comments_count']
          : int.tryParse(json['comments_count']?.toString() ?? '') ??
              json['commentsCount'] as int? ??
              json['comment_count'] as int? ??
              0,
      avatarUrl: json['avatar_url']?.toString(),
      totalLikes: json['total_likes'] is int
          ? json['total_likes']
          : int.tryParse(json['total_likes']?.toString() ?? '') ?? 0,
      isLiked: json['is_liked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'user_id': userId,
      'user_name': userName,
      'created_at': createdAt.toIso8601String(),
      'comments_count': commentsCount,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'total_likes': totalLikes,
      'is_liked': isLiked,
    };
  }

  Post copyWith({
    String? title,
    String? content,
    int? commentsCount,
    String? avatarUrl,
    int? totalLikes,
    bool? isLiked,
  }) {
    return Post(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      userId: userId,
      userName: userName,
      createdAt: createdAt,
      commentsCount: commentsCount ?? this.commentsCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalLikes: totalLikes ?? this.totalLikes,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }

  /// 🕒 Formato de fecha relativo estilo YouTube (hace 2 d, hace 3 h, etc.)
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return "hace $years año${years > 1 ? 's' : ''}";
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return "hace $months mes${months > 1 ? 'es' : ''}";
    } else if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return "hace $weeks sem";
    } else if (difference.inDays >= 1) {
      return "hace ${difference.inDays} d";
    } else if (difference.inHours >= 1) {
      return "hace ${difference.inHours} h";
    } else if (difference.inMinutes >= 1) {
      return "hace ${difference.inMinutes} min";
    } else {
      return "hace un momento";
    }
  }
}
