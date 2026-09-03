import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:eterlotto/models/post.dart';
import 'package:eterlotto/models/comment.dart';
import 'package:eterlotto/services/cache_service.dart';
import 'package:eterlotto/services/push_notification_service.dart';

import '../utils/secure_storage_helper.dart';

class ApiService {
  static const String baseUrl = "https://pry-dataloto.onrender.com";
  static final _storage = AppSecureStorage.instance;

  /// Headers dinámicos, con o sin token
  static Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    String? token;
    if (withAuth) {
      await ensureValidSession();
      token = await _storage.read(key: "auth_token");
    }

    return {
      "Content-Type": "application/json",
      if (withAuth && token != null && token.isNotEmpty)
        "Authorization": "Bearer $token",
    };
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await post("/login", {
        "email": email,
        "password": password,
      }, withAuth: false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data["access_token"];
        final refreshToken = data["refresh_token"];
        final user = data["user"];

        final userId = user?["id"];
        final userName = user?["name"];
        final userEmail = user?["email"];
        final paisId = user?["pais_id"];
        final paisNombre = user?["pais_nombre"];
        final departamentoId = user?["departamento_id"];
        final departamentoNombre = user?["departamento_nombre"];

        if (accessToken != null) {
          await _storage.write(key: "auth_token", value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: "refresh_token", value: refreshToken);
          }

          if (userId != null) {
            await _storage.write(key: "user_id", value: userId.toString());
          }
          if (userName != null) {
            await _storage.write(key: "name", value: userName);
          }
          if (userEmail != null) {
            await _storage.write(key: "email", value: userEmail);
          }
          if (paisId != null) {
            await _storage.write(key: "pais_id", value: paisId.toString());
          }
          if (paisNombre != null) {
            await _storage.write(key: "pais_nombre", value: paisNombre);
          }
          if (departamentoId != null) {
            await _storage.write(
              key: "departamento_id",
              value: departamentoId.toString(),
            );
          }
          if (departamentoNombre != null) {
            await _storage.write(
              key: "departamento_nombre",
              value: departamentoNombre,
            );
          }

          final avatarUrl = user?["avatar_url"];
          if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
            await _storage.write(key: "avatar_url", value: avatarUrl.toString());
          }
          final authProvider = user?["auth_provider"];
          if (authProvider != null) {
            await _storage.write(key: "auth_provider", value: authProvider.toString());
          }
          final telefono = user?["telefono"];
          if (telefono != null) {
            await _storage.write(key: "telefono", value: telefono.toString());
          }
          final idioma = user?["idioma"];
          if (idioma != null) {
            await _storage.write(key: "idioma", value: idioma.toString());
          }

          // 🔥 Sincronizar token FCM con el usuario autenticado
          PushNotificationService.syncToken();

          return {
            'success': true,
            'access_token': accessToken,
            'refresh_token': refreshToken,
            'user_id': userId?.toString(),
            'name': userName,
            'email': userEmail,
            'pais_id': paisId?.toString(),
            'pais_nombre': paisNombre,
            'departamento_id': departamentoId?.toString(),
            'departamento_nombre': departamentoNombre,
            'avatar_url': avatarUrl,
            'auth_provider': authProvider,
            'is_premium': user?['is_premium'] == true,
          };
        }

        return {'success': false, 'error': 'No access_token in response', 'message': 'No access_token in response'};
      } else {
        String errorDetail = 'Credenciales inválidas';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map) {
            errorDetail = errBody['detail']?.toString() ?? errBody['message']?.toString() ?? errorDetail;
          }
        } catch (_) {}
        return {
          'success': false,
          'error': errorDetail,
          'message': errorDetail,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> socialLogin(
    String provider,
    String token,
  ) async {
    try {
      final response = await post("/auth/social-login", {
        "provider": provider,
        "token": token,
      }, withAuth: false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data["access_token"];
        final refreshToken = data["refresh_token"];
        final user = data["user"];

        final userId = user?["id"];
        final userName = user?["name"];
        final userEmail = user?["email"];
        final paisId = user?["pais_id"];
        final paisNombre = user?["pais_nombre"];
        final departamentoId = user?["departamento_id"];
        final departamentoNombre = user?["departamento_nombre"];

        if (accessToken != null) {
          await _storage.write(key: "auth_token", value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: "refresh_token", value: refreshToken);
          }

          if (userId != null) {
            await _storage.write(key: "user_id", value: userId.toString());
          }
          if (userName != null) {
            await _storage.write(key: "name", value: userName);
          }
          if (userEmail != null) {
            await _storage.write(key: "email", value: userEmail);
          }
          if (paisId != null) {
            await _storage.write(key: "pais_id", value: paisId.toString());
          }
          if (paisNombre != null) {
            await _storage.write(key: "pais_nombre", value: paisNombre);
          }
          if (departamentoId != null) {
            await _storage.write(
              key: "departamento_id",
              value: departamentoId.toString(),
            );
          }
          if (departamentoNombre != null) {
            await _storage.write(
              key: "departamento_nombre",
              value: departamentoNombre,
            );
          }

          final avatarUrl = user?["avatar_url"];
          if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
            await _storage.write(key: "avatar_url", value: avatarUrl.toString());
          }
          final authProvider = user?["auth_provider"] ?? provider;
          await _storage.write(key: "auth_provider", value: authProvider.toString());

          // 🔥 Sincronizar token FCM con el usuario autenticado
          PushNotificationService.syncToken();

          return {
            'success': true,
            'access_token': accessToken,
            'refresh_token': refreshToken,
            'user': user,
          };
        }
        return {'success': false, 'error': 'No access_token in response'};
      } else {
        return {
          'success': false,
          'error': 'Social login failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 🔓 LOGOUT
  static Future<void> logout() async {
    await _storage.delete(key: "auth_token");
    await _storage.delete(key: "user_id");
  }

  /// 🔑 Obtener token guardado
  static Future<String?> getToken() async {
    return await _storage.read(key: "auth_token");
  }

  /// Intentar refrescar el access_token usando refresh_token
  static Future<bool> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: "refresh_token");
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final encodedToken = Uri.encodeComponent(refreshToken);
      final response = await http
          .post(
            Uri.parse("$baseUrl/refresh?refresh_token=$encodedToken"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"refresh_token": refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data["access_token"];
        final newRefreshToken = data["refresh_token"];

        if (newAccessToken != null) {
          await _storage.write(key: "auth_token", value: newAccessToken);
          if (newRefreshToken != null) {
            await _storage.write(key: "refresh_token", value: newRefreshToken);
          }

          // Extraer y persistir user_id
          try {
            final parts = (newAccessToken as String).split('.');
            if (parts.length == 3) {
              final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
              final pData = jsonDecode(payload);
              final sub = pData['sub'];
              if (sub != null) {
                await _storage.write(key: "user_id", value: sub.toString());
              }
            }
          } catch (_) {}

          return true;
        }
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// ✅ Validar si el token sigue vigente
  static Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload);

      final exp = data['exp'];
      if (exp == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  /// 🔁 Asegura sesión válida (valida o refresca)
  static Future<bool> ensureValidSession() async {
    if (await isTokenValid()) {
      return true;
    }

    final refreshed = await refreshAccessToken();
    if (refreshed) {
      return true;
    }

    return false;
  }

  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    final url = Uri.parse('$baseUrl/users/$userId'); // 👈 Usa tu backend

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Error al eliminar usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// 🔥 Actualizar el token de notificaciones FCM (ID del celular)
  static Future<bool> updateFCMToken(String fcmToken) async {
    final userId = await getUserId();
    if (userId == null) return false;

    try {
      final response = await post("/users/fcm_token", {
        "user_id": userId,
        "fcm_token": fcmToken
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("⚠️ Error actualizando FCM token: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: await _getHeaders(withAuth: true),
      body: json.encode(updateData),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      final Map<String, dynamic> rawUser = jsonData['user'];

      return {
        "success": jsonData['success'] as bool? ?? false,
        "message": jsonData['message']?.toString() ?? '',
        "user": {
          "id": (rawUser['id'] is int)
              ? rawUser['id']
              : int.tryParse(rawUser['id'].toString()) ?? 0,
          "name": rawUser['name']?.toString() ?? '',
          "email": rawUser['email']?.toString() ?? '',
          "pais_id": (rawUser['pais_id'] is int)
              ? rawUser['pais_id']
              : int.tryParse(rawUser['pais_id'].toString()),
          "pais_nombre": rawUser['pais_nombre']?.toString() ?? '',
          "departamento_id": (rawUser['departamento_id'] is int)
              ? rawUser['departamento_id']
              : int.tryParse(rawUser['departamento_id'].toString()),
          "departamento_nombre":
              rawUser['departamento_nombre']?.toString() ?? '',
          "avatar_url": rawUser['avatar_url']?.toString(),
          "auth_provider": rawUser['auth_provider']?.toString(),
          "telefono": rawUser['telefono']?.toString(),
          "idioma": rawUser['idioma']?.toString(),
        },
      };
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMsg =
          errorData['detail']?.toString() ?? 'Error al actualizar usuario';
      throw Exception(errorMsg);
    }
  }

  /// 🖼️ Obtener avatar guardado
  static Future<String?> getAvatarUrl() async {
    return await _storage.read(key: "avatar_url");
  }

  /// 🔒 Obtener proveedor de autenticación guardado
  static Future<String?> getAuthProvider() async {
    return await _storage.read(key: "auth_provider");
  }

  /// 🔑 Obtener userId guardado (con fallback robusto a JWT)
  static Future<int?> getUserId() async {
    try {
      final userIdStr = await _storage.read(key: "user_id");
      if (userIdStr != null && userIdStr.isNotEmpty && userIdStr != "null") {
        final parsed = int.tryParse(userIdStr);
        if (parsed != null && parsed > 0) return parsed;
      }

      // Fallback: Decodificar el token de autenticación
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final data = jsonDecode(payload);
          final sub = data['sub'] ?? data['user_id'] ?? data['id'];
          if (sub != null) {
            final parsed = int.tryParse(sub.toString());
            if (parsed != null && parsed > 0) {
              await _storage.write(key: "user_id", value: parsed.toString());
              return parsed;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// 📅 Calcular o normalizar la fecha del próximo sorteo para guardar jugadas
  static String getProximoSorteoFecha(String loteriaName, {String? fechaPrediccion, String? ultimoSorteoFecha}) {
    if (fechaPrediccion != null && fechaPrediccion.trim().isNotEmpty) {
      final clean = fechaPrediccion.trim().split("T").first;
      if (clean.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(clean.substring(0, 10))) {
        return clean.substring(0, 10);
      }
    }

    DateTime baseDate = DateTime.now();
    if (ultimoSorteoFecha != null && ultimoSorteoFecha.trim().isNotEmpty) {
      final clean = ultimoSorteoFecha.trim().split("T").first;
      final parsed = DateTime.tryParse(clean);
      if (parsed != null) {
        baseDate = parsed;
      }
    }

    final DateTime next = baseDate.add(const Duration(days: 1));
    return "${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}";
  }

  /// 🎲 Crear jugada SIN TOKEN (MiLoto)
  static Future<Map<String, dynamic>> crearJugada(
    List<int> numeros,
    String userId, {
    String? fechaSorteo,
  }) async {
    final Map<String, dynamic> payload = {
      "numeros": numeros,
      "user_id": userId,
    };
    if (fechaSorteo != null && fechaSorteo.isNotEmpty) {
      payload["fecha_sorteo"] = fechaSorteo;
      payload["fecha"] = fechaSorteo;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_mloto"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      CacheService.registrarJugadaOptimista("mloto");
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {"status": "ok"};
      }
    } else {
      throw Exception(
        "Error al crear jugada: ${response.statusCode} ${response.body}, $userId",
      );
    }
  }

  static Future<List<dynamic>> listarJugadasMloto({
    String? fecha,
    int retries = 3,
    int delayMs = 500,
  }) async {
    final userId = await getUserId();

    if (userId == null) {
      return [];
    }

    final queryParams = "user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}${fecha != null && fecha.isNotEmpty ? "&fecha=$fecha" : ""}";

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/jugadas_mloto?$queryParams",
          ),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data;
          } else {
            throw Exception("Formato de respuesta inválido: no es una lista");
          }
        } else {
          throw Exception(
            "Error al listar jugadas: ${response.statusCode} ${response.body}",
          );
        }
      } catch (e) {
        if (attempt == retries) {
          throw Exception("Error al listar jugadas: $e");
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return [];
  }

  static Future<bool> borrarJugadaMloto(int jugadaId, String userId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/jugadas_mloto/$jugadaId?user_id=$userId"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      CacheService.invalidarCachesDeJugadas(specificRoute: "mloto");
      return true;
    } else {
      throw Exception(
        "Error al borrar jugada: ${response.statusCode} ${response.body}",
      );
    }
  }

  ////////////////////// seccion crear, lista y borrar jugadas bloto  //////////////////////////
  /// 🎲 Crear jugada BLOTO SIN TOKEN
  static Future<Map<String, dynamic>> crearJugadaBloto(
    List<int> numeros,
    String userId, {
    String? fechaSorteo,
  }) async {
    if (userId.isEmpty) {
      throw Exception("El userId enviado desde el front está vacío");
    }

    final Map<String, dynamic> payload = {
      "numeros": numeros,
      "user_id": userId,
    };
    if (fechaSorteo != null && fechaSorteo.isNotEmpty) {
      payload["fecha_sorteo"] = fechaSorteo;
      payload["fecha"] = fechaSorteo;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_bloto"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      CacheService.registrarJugadaOptimista("bloto");
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {"status": "ok"};
      }
    }

    throw Exception(
      "Error al crear jugada: ${response.statusCode} ${response.body}",
    );
  }

  static Future<List<dynamic>> listarJugadasBloto({
    String? fecha,
    int retries = 3,
    int delayMs = 500,
  }) async {
    final userId = await getUserId();

    if (userId == null) {
      return [];
    }

    final queryParams = "user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}${fecha != null && fecha.isNotEmpty ? "&fecha=$fecha" : ""}";

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/jugadas_bloto?$queryParams",
          ),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data;
          } else {
            throw Exception("Formato de respuesta inválido: no es una lista");
          }
        } else {
          throw Exception(
            "Error al listar jugadas: ${response.statusCode} ${response.body}",
          );
        }
      } catch (e) {
        if (attempt == retries) {
          throw Exception("Error al listar jugadas: $e");
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return [];
  }

  /// 🗑️ Borrar jugada BLOTO SIN TOKEN
  static Future<bool> borrarJugadaBloto(int jugadaId, String userId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/jugadas_bloto/$jugadaId?user_id=$userId"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      CacheService.invalidarCachesDeJugadas(specificRoute: "bloto");
      return true;
    } else {
      throw Exception(
        "Error al borrar jugada: ${response.statusCode} ${response.body}",
      );
    }
  }

  /// 🎲 Crear jugada genérica
  static Future<Map<String, dynamic>> crearJugadaGenerica(
    String loteriaName,
    List<int> numeros,
    String userId, {
    int? balotaRoja,
    String? fechaSorteo,
  }) async {
    if (userId.isEmpty) {
      throw Exception("El userId enviado está vacío");
    }

    String route = loteriaName.trim().toLowerCase();
    if (route == "colorloto") {
      route = "cloto";
    }

    final List<int> numerosParaGuardar = (balotaRoja != null)
        ? (numeros.isNotEmpty && numeros.last == balotaRoja ? numeros : [...numeros, balotaRoja])
        : numeros;

    final Map<String, dynamic> payload = {
      "numeros": numerosParaGuardar,
      "user_id": userId,
    };
    if (balotaRoja != null) {
      payload["balota_roja"] = balotaRoja;
      payload["balotaroja"] = balotaRoja;
    }
    if (fechaSorteo != null && fechaSorteo.isNotEmpty) {
      payload["fecha_sorteo"] = fechaSorteo;
      payload["fecha"] = fechaSorteo;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_$route"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      CacheService.registrarJugadaOptimista(route);
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {"status": "ok"};
    }
    throw Exception("Error al crear jugada $route: ${response.statusCode}");
  }

  static Future<List<dynamic>> listarJugadasGenerica(
    String loteriaName, {
    String? fecha,
    int retries = 3,
    int delayMs = 500,
  }) async {
    final userId = await getUserId();

    if (userId == null) return [];

    // Mapeo especial para ColorLoto
    String route = loteriaName.trim().toLowerCase();
    if (route == "colorloto") {
      route = "cloto";
    }

    final queryParams = "user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}${fecha != null && fecha.isNotEmpty ? "&fecha=$fecha" : ""}";

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse("$baseUrl/jugadas_$route?$queryParams"),
          headers: {"Content-Type": "application/json"},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) return data;
        } else {
          debugPrint("⚠️ HTTP ${response.statusCode} al listar jugadas ($route): ${response.body}");
        }
      } catch (e) {
        if (attempt == retries) {
          debugPrint("❌ Error final al listar jugadas ($route): $e");
        } else {
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
    return [];
  }

  /// 🗑️ Borrar jugada genérica
  static Future<bool> borrarJugadaGenerica(String loteriaName, int jugadaId, String userId) async {
    String route = loteriaName.trim().toLowerCase();
    if (route == "colorloto") {
      route = "cloto";
    }
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/jugadas_$route/$jugadaId?user_id=$userId"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        CacheService.invalidarCachesDeJugadas(specificRoute: route);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ Error al borrar jugada ($route/$jugadaId): $e");
      return false;
    }
  }

  /// ✏️ Actualizar jugada genérica (con soporte directo PUT y fallback inteligente)
  static Future<bool> actualizarJugadaGenerica(
    String loteriaName,
    int jugadaId,
    List<int> numeros,
    String userId, {
    int? balotaRoja,
    String? fechaSorteo,
  }) async {
    if (userId.isEmpty) return false;
    String route = loteriaName.trim().toLowerCase();
    if (route == "colorloto") {
      route = "cloto";
    }

    final List<int> numerosParaGuardar = (balotaRoja != null)
        ? (numeros.isNotEmpty && numeros.last == balotaRoja ? numeros : [...numeros, balotaRoja])
        : numeros;

    final Map<String, dynamic> payload = {
      "numeros": numerosParaGuardar,
      "user_id": userId,
      "loteria_route": route,
    };
    if (balotaRoja != null) {
      payload["balota_roja"] = balotaRoja;
    }
    if (fechaSorteo != null && fechaSorteo.isNotEmpty) {
      payload["fecha_sorteo"] = fechaSorteo;
    }

    try {
      final token = await getToken();
      final headers = {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      };

      // 1. Intentar endpoint dinámico PUT en el backend
      var putResponse = await http.put(
        Uri.parse("$baseUrl/jugadas_$route/$jugadaId"),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (putResponse.statusCode == 200) {
        CacheService.invalidarCachesDeJugadas(specificRoute: route);
        return true;
      }

      // 2. Intentar endpoint unificado PUT
      putResponse = await http.put(
        Uri.parse("$baseUrl/jugadas/$jugadaId"),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (putResponse.statusCode == 200) {
        CacheService.invalidarCachesDeJugadas(specificRoute: route);
        return true;
      }

      // 3. Si el backend en Render aún no ha desplegado el PUT (404 o 405), fallback: borrar y crear
      if (putResponse.statusCode == 404 || putResponse.statusCode == 405) {
        final deleted = await borrarJugadaGenerica(route, jugadaId, userId);
        if (deleted) {
          await crearJugadaGenerica(
            route,
            numeros,
            userId,
            balotaRoja: balotaRoja,
            fechaSorteo: fechaSorteo,
          );
          CacheService.invalidarCachesDeJugadas(specificRoute: route);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint("⚠️ Error al actualizar jugada ($route/$jugadaId): $e");
      try {
        final deleted = await borrarJugadaGenerica(route, jugadaId, userId);
        if (deleted) {
          await crearJugadaGenerica(
            route,
            numeros,
            userId,
            balotaRoja: balotaRoja,
            fechaSorteo: fechaSorteo,
          );
          CacheService.invalidarCachesDeJugadas(specificRoute: route);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  /// 🔍 Obtener lista de loterías donde el usuario tiene jugadas
  static Future<List<String>> getLoteriasConJugadas() async {
    final userId = await getUserId();
    if (userId == null) return [];

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/mis_loterias_activas?user_id=$userId"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      }
    } catch (e) {
      debugPrint("Error obteniendo loterías activas: $e");
    }
    return [];
  }

  /// 🔍 Obtener mapa de loterías con conteo de jugadas {route: count}
  static Future<Map<String, int>> getLoteriasConConteo() async {
    final userId = await getUserId();
    if (userId == null) return {};

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/mis_loterias_con_conteo?user_id=$userId"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && !decoded.containsKey("error")) {
          return decoded.map((key, value) => MapEntry(key.toString().toLowerCase(), int.tryParse(value.toString()) ?? 0));
        }
      }
    } catch (_) {}

    // Fallback garantizado para Render
    try {
      final activas = await getLoteriasConJugadas();
      if (activas.isEmpty) return {};

      final Map<String, int> conteos = {};
      await Future.wait(
        activas.map((r) async {
          try {
            final list = await listarJugadasGenerica(r, retries: 1);
            conteos[r.toLowerCase()] = list.length;
          } catch (_) {
            conteos[r.toLowerCase()] = 1;
          }
        }),
      );
      return conteos;
    } catch (e) {
      debugPrint("Error en conteos fallback: $e");
    }
    return {};
  }

  /// 🔍 Obtener mapa de loterías con información de jugadas {route: {count: int, fecha: String?}}
  static Future<Map<String, Map<String, dynamic>>> getLoteriasInfoJugadas() async {
    final userId = await getUserId();
    if (userId == null) return {};

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/mis_loterias_info?user_id=$userId"),
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && !decoded.containsKey("error")) {
          return decoded.map((key, value) => MapEntry(key.toString().toLowerCase(), Map<String, dynamic>.from(value as Map)));
        }
      }
    } catch (_) {}

    // Fallback garantizado para Render
    try {
      final activas = await getLoteriasConJugadas();
      if (activas.isEmpty) return {};

      final Map<String, Map<String, dynamic>> infoMap = {};
      await Future.wait(
        activas.map((r) async {
          try {
            final list = await listarJugadasGenerica(r, retries: 1);
            if (list.isNotEmpty) {
              final fechas = list
                  .map((j) => (j['fecha_sorteo'] ?? (j['fecha_guardado'] != null ? j['fecha_guardado'].toString().substring(0, 10) : null))?.toString())
                  .where((f) => f != null && f.isNotEmpty)
                  .cast<String>()
                  .toList();
              
              fechas.sort();
              final latestFecha = fechas.isNotEmpty ? fechas.last : null;
              infoMap[r.toLowerCase()] = {
                "count": list.length,
                "fecha": latestFecha,
              };
            } else {
              infoMap[r.toLowerCase()] = {
                "count": 1,
                "fecha": null,
              };
            }
          } catch (_) {
            infoMap[r.toLowerCase()] = {
              "count": 1,
              "fecha": null,
            };
          }
        }),
      );
      return infoMap;
    } catch (e) {
      debugPrint("Error obteniendo info de jugadas: $e");
    }
    return {};
  }


  /// GET genérico con timeout, auto-retry y soporte para forceRefresh
  static Future<http.Response> get(
    String endpoint, {
    bool withAuth = true,
    bool forceRefresh = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var headers = await _getHeaders(withAuth: withAuth);
    if (forceRefresh) {
      headers["Cache-Control"] = "no-cache";
      headers["Pragma"] = "no-cache";
    }

    var response = await http
        .get(Uri.parse("$baseUrl$endpoint"), headers: headers)
        .timeout(timeout);

    if (withAuth && response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _getHeaders(withAuth: true);
        if (forceRefresh) {
          headers["Cache-Control"] = "no-cache";
          headers["Pragma"] = "no-cache";
        }
        response = await http
            .get(Uri.parse("$baseUrl$endpoint"), headers: headers)
            .timeout(timeout);
      }
    }

    return response;
  }

  /// POST genérico con auto-retry si el token expiró y timeout
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var headers = await _getHeaders(withAuth: withAuth);
    var response = await http
        .post(
          Uri.parse("$baseUrl$endpoint"),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (withAuth && response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _getHeaders(withAuth: true);
        response = await http
            .post(
              Uri.parse("$baseUrl$endpoint"),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(timeout);
      }
    }

    return response;
  }

  /// PUT genérico con auto-retry y timeout
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var headers = await _getHeaders(withAuth: withAuth);
    var response = await http
        .put(
          Uri.parse("$baseUrl$endpoint"),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (withAuth && response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _getHeaders(withAuth: true);
        response = await http
            .put(
              Uri.parse("$baseUrl$endpoint"),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(timeout);
      }
    }

    return response;
  }

  /// DELETE genérico con auto-retry si el token expiró y timeout
  static Future<http.Response> delete(
    String endpoint, {
    bool withAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var headers = await _getHeaders(withAuth: withAuth);
    var response = await http
        .delete(
          Uri.parse("$baseUrl$endpoint"),
          headers: headers,
        )
        .timeout(timeout);

    if (withAuth && response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _getHeaders(withAuth: true);
        response = await http
            .delete(
              Uri.parse("$baseUrl$endpoint"),
              headers: headers,
            )
            .timeout(timeout);
      }
    }

    return response;
  }

  //////////////////// SECCIÓN COMENTARIOS Y POSTS ////////////////////

  static Future<Post> createPost(String title, String content) async {
    await ensureValidSession();

    final headers = await _getHeaders(withAuth: true);

    final response = await http.post(
      Uri.parse("$baseUrl/posts"),
      headers: headers,
      body: jsonEncode({"title": title, "content": content}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Post.fromJson(data);
    } else {
      throw Exception(
        "Error al crear post: ${response.statusCode} ${response.body}",
      );
    }
  }

  // 🔹 Obtener todos los posts
  static Future<List<Post>> getPosts() async {
    await ensureValidSession();

    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse("$baseUrl/posts"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Post.fromJson(json)).toList();
    } else {
      throw Exception("Error al obtener posts: ${response.statusCode}");
    }
  }

  // 🔹 Actualizar un post (PUT)
  static Future<Post> updatePost(int id, String title, String content) async {
    await ensureValidSession();

    final response = await http.put(
      Uri.parse('$baseUrl/posts/$id'),
      headers: {
        'Authorization': 'Bearer ${await getToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title, 'content': content}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Post.fromJson(data);
    } else {
      throw Exception("Error al actualizar el post: ${response.statusCode}");
    }
  }

  // 🔹 Eliminar un post (DELETE)
  static Future<void> deletePost(int id) async {
    await ensureValidSession();

    final headers = await _getHeaders();

    final response = await http.delete(
      Uri.parse("$baseUrl/posts/$id"),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Error al eliminar el post: ${response.statusCode}");
    }
  }


  // Crear un comentario o respuesta
  static Future<Comment> createComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    await ensureValidSession();

    final payloadContent =
        parentId != null ? "[replyTo:$parentId] $content" : content;
    final body = <String, dynamic>{
      "content": payloadContent,
    };
    if (parentId != null) {
      body["parent_id"] = parentId;
    }

    final response = await post("/posts/$postId/comments", body, withAuth: true);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Comment.fromJson(data);
    } else {
      throw Exception("Error al crear comentario: ${response.statusCode}");
    }
  }

  // Obtener comentarios de un post
  static Future<List<Comment>> getComments(int postId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/posts/$postId/comments"),
      headers: {
        "Content-Type": "application/json",
        if (await getToken() != null)
          "Authorization": "Bearer ${await getToken()}",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Comment.fromJson(json)).toList();
    } else {
      throw Exception("Error al obtener comentarios: ${response.statusCode}");
    }
  }

  static Future<void> deleteComment(int commentId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/comments/$commentId"),
      headers: {"Authorization": "Bearer ${await getToken()}"},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Error al eliminar comentario");
    }
  }

  static Future<List<Map<String, dynamic>>> getCiudades() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ciudades'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> data = jsonData['data']; // 👈 Aquí llega la lista

      // 🔹 Aseguramos que devuelva un List<Map<String, dynamic>>
      return data
          .map<Map<String, dynamic>>(
            (e) => {
              "id": (e['id'] is int)
                  ? e['id']
                  : int.tryParse(e['id'].toString()) ?? 0,
              "nombre": e['nombre']?.toString() ?? '',
            },
          )
          .toList();
    } else {
      throw Exception('Error al obtener ciudades');
    }
  }

  static Future<List<Map<String, dynamic>>> getCategorias() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/categorias'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data = decoded is Map && decoded.containsKey('data')
            ? decoded['data']
            : (decoded is List ? decoded : []);

        final result = data
            .map<Map<String, dynamic>>(
              (e) => {
                "id": (e['id'] is int)
                    ? e['id']
                    : int.tryParse(e['id'].toString()) ?? 0,
                "nombre": e['nombre']?.toString() ?? '',
              },
            )
            .toList();

        if (result.isNotEmpty) {
          CacheService.setJson('categorias_list_cache', result);
        }
        return result;
      }
    } catch (_) {}

    // Fallback de caché local
    final cached = await CacheService.getJson('categorias_list_cache');
    if (cached is List && cached.isNotEmpty) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return [];
  }

  // 📢 Obtener anuncios filtrados (por ID)
  static Future<List<Map<String, dynamic>>> getPublicidades({
    int? paisId,
    int? departamentoId,
    int? ciudadId,
    int? categoriaId,
    String? titulo,
  }) async {
    try {
      // 🧱 1. Construir la URL base con filtros dinámicos
      final Map<String, String> queryParams = {};

      if (paisId != null && paisId > 0) {
        queryParams['pais_id'] = paisId.toString();
      }
      if (departamentoId != null && departamentoId > 0) {
        queryParams['departamento_id'] = departamentoId.toString();
      }
      if (ciudadId != null && ciudadId > 0) {
        queryParams['ciudad_id'] = ciudadId.toString();
      }
      if (categoriaId != null && categoriaId > 0) {
        queryParams['categoria_id'] = categoriaId.toString();
      }
      if (titulo != null && titulo.trim().isNotEmpty) {
        queryParams['titulo'] = titulo.trim();
      }

      // 🚀 2. Construir URI con parámetros
      final uri = Uri.parse(
        "$baseUrl/publicidad",
      ).replace(queryParameters: queryParams);

      // 📬 3. Enviar solicitud HTTP
      final response = await http.get(
        uri,
        headers: await _getHeaders(withAuth: true),
      );

      // ✅ 4. Validar estado de la respuesta
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<Map<String, dynamic>> resultList = [];
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final List<dynamic> data = decoded['data'];
          resultList = List<Map<String, dynamic>>.from(data);
        } else if (decoded is List) {
          resultList = List<Map<String, dynamic>>.from(decoded);
        }

        final localFavs = await getFavoritosLocales();
        for (var ad in resultList) {
          final int? id = ad["id"] is int ? ad["id"] : int.tryParse(ad["id"]?.toString() ?? "");
          if (id != null && localFavs.contains(id)) {
            ad["is_favorite"] = true;
          }
        }
        return resultList;
      } else {
        throw Exception(
          "Error ${response.statusCode}: ${response.reasonPhrase}",
        );
      }
    } catch (e) {
      throw Exception(
        "No se pudieron obtener los anuncios. Intenta más tarde.",
      );
    }
  }

  // ✅ Obtener lista de países
  static Future<List<Map<String, dynamic>>> getPaises() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/paises'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data = decoded is Map && decoded.containsKey('data')
            ? decoded['data']
            : (decoded is List ? decoded : []);

        final result = data
            .map<Map<String, dynamic>>(
              (e) => {
                "id": (e['id'] is int)
                    ? e['id']
                    : int.tryParse(e['id'].toString()) ?? 0,
                "nombre": e['nombre']?.toString() ?? '',
              },
            )
            .toList();

        if (result.isNotEmpty) {
          CacheService.setJson('paises_list_cache', result);
        }
        return result;
      }
    } catch (_) {}

    // Fallback caché
    final cached = await CacheService.getJson('paises_list_cache');
    if (cached is List && cached.isNotEmpty) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return [];
  }

  // ✅ Obtener departamentos por país (usa el id del país)
  static Future<List<Map<String, dynamic>>> getDepartamentosPorPais(
    int paisId,
  ) async {
    return getDepartamentos(paisId: paisId);
  }

  // --- Obtener Departamentos por país ---
  static Future<List<Map<String, dynamic>>> getDepartamentos({
    required int paisId,
  }) async {
    final cacheKey = 'departamentos_cache_$paisId';
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/departamentos/$paisId'),
            headers: {"Content-Type": "application/json"},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        final List<dynamic> data = decoded is Map && decoded.containsKey('data')
            ? decoded['data']
            : (decoded is List ? decoded : []);

        final result = data
            .map<Map<String, dynamic>>(
              (e) => {
                "id": (e['id'] is int)
                    ? e['id']
                    : int.tryParse(e['id'].toString()) ?? 0,
                "nombre": e['nombre']?.toString() ?? '',
              },
            )
            .toList();

        if (result.isNotEmpty) {
          CacheService.setJson(cacheKey, result);
        }
        return result;
      }
    } catch (_) {}

    // Fallback caché
    final cached = await CacheService.getJson(cacheKey);
    if (cached is List && cached.isNotEmpty) {
      return List<Map<String, dynamic>>.from(cached);
    }
    return [];
  }

  // --- Obtener Ciudades por departamento ---
  static Future<List<Map<String, dynamic>>> getCiudadesPorDepartamento({
    required int departamentoId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/ciudades?departamento_id=$departamentoId',
      ), // 👈 Corregido: Usa query param en lugar de path param para evitar 404
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      if (jsonData["success"] == true && jsonData["data"] is List) {
        final List<dynamic> data = jsonData["data"];
        return data
            .map<Map<String, dynamic>>(
              (e) => {
                "id": (e['id'] is int)
                    ? e['id']
                    : int.tryParse(e['id'].toString()) ?? 0,
                "nombre": e['nombre']?.toString() ?? '',
              },
            )
            .toList();
      } else {
        throw Exception('⚠️ Respuesta inesperada del servidor.');
      }
    } else {
      throw Exception('❌ Error al obtener ciudades (${response.statusCode}).');
    }
  }

  // --- CREAR PUBLICIDAD ---
  static Future<Map<String, dynamic>> crearPublicidad(
    Map<String, dynamic> data,
  ) async {
    // ✅ Validar y auto-refrescar token antes de enviar
    await ensureValidSession();

    // ✅ Obtener token actualizado
    final token = await getToken();
    if (token == null) {
      throw Exception('⚠️ No se encontró un token válido.');
    }

    // 🧩 Cuerpo limpio, asegurando que pais_id y departamento_id estén presentes
    final Map<String, dynamic> body = {
      "categoria_id": data["categoria_id"],
      "pais_id": data["pais_id"],
      "departamento_id": data["departamento_id"],
      "ciudad_id": data["ciudad_id"],
      "titulo": data["titulo"],
      "descripcion": data["descripcion"],
      "imagen_url": data["imagen_url"],
      "telefono": data["telefono"],
      "facebook_url": data["facebook_url"],
      "instagram_url": data["instagram_url"],
      "whatsapp_url": data["whatsapp_url"],
      "tiktok_url": data["tiktok_url"],
      "pagina_url": data["pagina_url"],
      "direccion": data["direccion"],
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/publicidad'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        return json;
      } else {
        // 🚨 Manejo explícito de errores del servidor FastAPI
        throw Exception(
          json['detail'] ?? json['message'] ?? 'Error al crear la publicidad',
        );
      }
    } catch (e) {
      // 🚨 Control total de excepciones de red o JSON
      throw Exception('Error de red o servidor: $e');
    }
  }

  // 🔹 Obtener mis anuncios
  static Future<List<Map<String, dynamic>>> getMisPublicidades() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/mis_publicidades'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Error al obtener mis publicidades');
    }
  }

  // 🔹 Eliminar anuncio
  static Future<void> eliminarPublicidad(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/publicidad/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la publicidad');
    }
  }

  static Future<Map<String, dynamic>> actualizarPublicidad(
    int id,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/publicidad/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al actualizar: ${response.body}');
    }
  }

  static const String _favsStorageKey = "usuario_publicidades_favoritas";

  // ⭐ Obtener conjunto de IDs favoritos guardados localmente
  static Future<Set<int>> getFavoritosLocales() async {
    try {
      final str = await _storage.read(key: _favsStorageKey);
      if (str != null && str.isNotEmpty) {
        final list = jsonDecode(str) as List<dynamic>;
        return list.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toSet();
      }
    } catch (_) {}
    return {};
  }

  // ⭐ Guardar o remover favorito localmente
  static Future<void> guardarFavoritoLocal(int publicidadId, bool isFavorite) async {
    try {
      final favs = await getFavoritosLocales();
      if (isFavorite) {
        favs.add(publicidadId);
      } else {
        favs.remove(publicidadId);
      }
      await _storage.write(key: _favsStorageKey, value: jsonEncode(favs.toList()));
    } catch (_) {}
  }

  // ⭐ Toggle Favorito en anuncio (con persistencia local instantánea)
  static Future<Map<String, dynamic>> toggleFavoritoPublicidad(int id) async {
    final localFavs = await getFavoritosLocales();
    final bool willBeFav = !localFavs.contains(id);
    await guardarFavoritoLocal(id, willBeFav);

    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final response = await http.post(
          Uri.parse('$baseUrl/publicidad/$id/favorito'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final res = json.decode(response.body);
          if (res is Map<String, dynamic> && res["is_favorite"] != null) {
            await guardarFavoritoLocal(id, res["is_favorite"] == true);
          }
          return res;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Toggle favorito remoto pendiente de sync: $e");
    }

    return {
      "success": true,
      "is_favorite": willBeFav,
      "total_votos": null,
      "is_destacado": null,
    };
  }

  // ⭐ Calificar anuncio con estrellas
  static Future<Map<String, dynamic>> calificarPublicidad(
    int id,
    int estrellas,
  ) async {
    await ensureValidSession();
    final token = await getToken();
    if (token == null) {
      throw Exception('Debes iniciar sesión para calificar');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/publicidad/$id/calificar'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({"estrellas": estrellas}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al calificar');
    }
  }

/////////////////////////// Loterias ////////////////////////////

  /// 📋 Listar loterías disponibles (por país o todas)
  static Future<List<dynamic>> getLoteriasPorPais([String? paisId]) async {
    final uri = (paisId != null && paisId.isNotEmpty)
        ? Uri.parse("$baseUrl/loterias?pais_id=$paisId")
        : Uri.parse("$baseUrl/loterias");

    final response = await http.get(
      uri,
      headers: await _getHeaders(withAuth: false),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      throw Exception("Formato inválido de loterías");
    } else {
      throw Exception(
        "Error al obtener loterías: ${response.statusCode}",
      );
    }
  }

  /// 🌐 Obtener todas las loterías de una sola petición
  static Future<List<dynamic>> getAllLoterias() async {
    return getLoteriasPorPais(null);
  }

  /// 🔮 Obtener predicción de IA, números probables y jackpot de una lotería
  static Future<Map<String, dynamic>> getPrediccionLoteria(String route) async {
    final cleanRoute = route.trim().toLowerCase();
    final uri = Uri.parse("$baseUrl/$cleanRoute");
    final response = await http
        .get(uri, headers: await _getHeaders(withAuth: false))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception("Formato inválido en predicción de $cleanRoute");
    } else {
      throw Exception("Error al obtener predicción ($cleanRoute): ${response.statusCode}");
    }
  }

  /// 📊 Obtener últimos sorteos de una lotería
  static Future<List<Map<String, dynamic>>> getUltimosResultados(String route) async {
    final cleanRoute = route.trim().toLowerCase();
    final uri = Uri.parse("$baseUrl/$cleanRoute/ultimos5");
    final response = await http
        .get(uri, headers: await _getHeaders(withAuth: false))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded["resultados"] is List) {
        return List<Map<String, dynamic>>.from(decoded["resultados"]);
      }
      return <Map<String, dynamic>>[];
    } else {
      throw Exception("Error al obtener últimos resultados ($cleanRoute): ${response.statusCode}");
    }
  }

  /// 📜 Obtener los 50 sorteos más recientes para visualización rápida en pantalla
  static Future<List<Map<String, dynamic>>> getHistorico50(String route) async {
    final cleanRoute = route.trim().toLowerCase();
    try {
      final uri = Uri.parse("$baseUrl/$cleanRoute/ultimos50");
      final response = await http
          .get(uri, headers: await _getHeaders(withAuth: false))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded["resultados"] is List) {
          return List<Map<String, dynamic>>.from(decoded["resultados"]);
        }
      }
    } catch (_) {}

    // Fallback garantizado: consultar getHistoricoCompleto y tomar los primeros 50
    try {
      final fullList = await getHistoricoCompleto(cleanRoute);
      return fullList.take(50).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// 📜 Obtener histórico completo de resultados de una lotería (para exportación)
  static Future<List<Map<String, dynamic>>> getHistoricoCompleto(String route) async {
    final cleanRoute = route.trim().toLowerCase();
    final uri = Uri.parse("$baseUrl/$cleanRoute/historico_completo");
    final response = await http
        .get(uri, headers: await _getHeaders(withAuth: false))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded["resultados"] is List) {
        return List<Map<String, dynamic>>.from(decoded["resultados"]);
      }
      return <Map<String, dynamic>>[];
    } else {
      throw Exception("Error al obtener histórico ($cleanRoute): ${response.statusCode}");
    }
  }

  /// 💎 Confirmar y registrar suscripción en la base de datos
  static Future<Map<String, dynamic>> confirmSubscription({
    required String productId,
    String? purchaseToken,
    String? orderId,
  }) async {
    try {
      final userIdStr = await getUserId();
      if (userIdStr == null) {
        return {'success': false, 'error': 'Usuario no autenticado'};
      }

      final response = await post(
        "/subscriptions/confirm",
        {
          "user_id": int.parse(userIdStr.toString()),
          "product_id": productId,
          "purchase_token": purchaseToken,
          "order_id": orderId,
          "status": "active",
        },
        withAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 💎 Consultar estado VIP del usuario desde la base de datos (fuente de verdad)
  static Future<bool> checkSubscriptionStatus() async {
    try {
      final userIdStr = await getUserId();
      if (userIdStr == null) return false;

      final response = await get("/subscriptions/status/$userIdStr", withAuth: true);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["is_premium"] == true;
      }
      return false;
    } catch (e) {
      debugPrint("Error verificando suscripción con backend: $e");
      return false;
    }
  }
}

