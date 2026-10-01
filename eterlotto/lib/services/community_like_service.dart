import 'dart:convert';

import 'package:eterlotto/services/api_service.dart';

class CommunityLikeService {
  static Future<Map<String, dynamic>> togglePostLike(int postId) async {
    final response = await ApiService.post(
      '/posts/$postId/like',
      const <String, dynamic>{},
      withAuth: true,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No fue posible actualizar el Me gusta');
    }
    final decoded = jsonDecode(response.body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  static Future<Map<String, dynamic>> toggleCommentLike(int commentId) async {
    final response = await ApiService.post(
      '/comments/$commentId/like',
      const <String, dynamic>{},
      withAuth: true,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No fue posible actualizar el Me gusta');
    }
    final decoded = jsonDecode(response.body);
    return Map<String, dynamic>.from(decoded as Map);
  }
}
