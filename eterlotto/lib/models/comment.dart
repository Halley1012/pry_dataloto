import 'package:intl/intl.dart';

class Comment {
  final int id;
  final int postId;
  final int userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final int? parentId;
  final String status;
  final String? moderationReason;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.status = 'active',
    this.moderationReason,
    this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    int? parsedParentId = json['parent_id'];
    String rawContent = json['content'] ?? '';

    if (parsedParentId == null && rawContent.contains('[replyTo:')) {
      final match = RegExp(r'\[replyTo:(\d+)\]').firstMatch(rawContent);
      if (match != null) {
        parsedParentId = int.tryParse(match.group(1) ?? '');
      }
    }

    final cleanContent = rawContent.replaceAll(RegExp(r'\[replyTo:\d+\]\s*'), '');

    DateTime? parsedUpdatedAt;
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    return Comment(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? '',
      content: cleanContent,
      createdAt: DateTime.parse(json['created_at'].toString()),
      parentId: parsedParentId,
      status: json['status'] ?? 'active',
      moderationReason: json['moderation_reason'],
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    };
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