import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dataloto/models/post.dart';
import 'package:dataloto/models/comment.dart';

class ApiService {
  static const String baseUrl = "https://pry-dataloto.onrender.com";
  static final _storage = const FlutterSecureStorage();

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
          };
        }

        return {'success': false, 'error': 'No access_token in response'};
      } else {
        return {
          'success': false,
          'error': 'Login failed with status ${response.statusCode}',
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
          return true;
        }
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 422) {
        await logout();
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

  static Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {"Content-Type": "application/json"},
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
        },
      };
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMsg =
          errorData['detail']?.toString() ?? 'Error al actualizar usuario';
      throw Exception(errorMsg);
    }
  }

  /// 🔑 Obtener userId guardado
  static Future<int?> getUserId() async {
    final userIdStr = await _storage.read(key: "user_id");
    return userIdStr != null ? int.tryParse(userIdStr) : null;
  }

  /// 🎲 Crear jugada SIN TOKEN
  static Future<Map<String, dynamic>> crearJugada(
    List<int> numeros,
    String userId,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_mloto"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"numeros": numeros, "user_id": userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw Exception("Formato de respuesta inválido: no es un objeto");
      }
    } else {
      throw Exception(
        "Error al crear jugada: ${response.statusCode} ${response.body}, $userId",
      );
    }
  }

  /// 📋 Listar jugadas SIN TOKEN
  static Future<List<dynamic>> listarJugadasMloto({
    int retries = 3,
    int delayMs = 500,
  }) async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');

    if (userId == null) {
      throw Exception("No se encontró user_id en el dispositivo");
    }

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/jugadas_mloto?user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}",
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
    String userId,
  ) async {
    if (userId.isEmpty) {
      throw Exception("El userId enviado desde el front está vacío");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_bloto"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"numeros": numeros, "user_id": userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        throw Exception("La API no devolvió un objeto JSON válido");
      }
    }

    throw Exception(
      "Error al crear jugada: ${response.statusCode} ${response.body}",
    );
  }

  /// 📋 Listar jugadas BLOTO SIN TOKEN
  static Future<List<dynamic>> listarJugadasBloto({
    int retries = 3,
    int delayMs = 500,
  }) async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');

    if (userId == null) {
      throw Exception("No se encontró user_id en el dispositivo");
    }

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(
            "$baseUrl/jugadas_bloto?user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}",
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
    String userId,
  ) async {
    if (userId.isEmpty) {
      throw Exception("El userId enviado está vacío");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/jugadas_$loteriaName"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"numeros": numeros, "user_id": userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    }
    throw Exception("Error al crear jugada $loteriaName: ${response.statusCode}");
  }

  /// 📋 Listar jugadas genéricas
  static Future<List<dynamic>> listarJugadasGenerica(String loteriaName) async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');

    if (userId == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/jugadas_$loteriaName?user_id=$userId&t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  /// 🗑️ Borrar jugada genérica
  static Future<bool> borrarJugadaGenerica(String loteriaName, int jugadaId, String userId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/jugadas_$loteriaName/$jugadaId?user_id=$userId"),
      headers: {"Content-Type": "application/json"},
    );
    return response.statusCode == 200;
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


  /// GET genérico
  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    return http.get(Uri.parse("$baseUrl$endpoint"), headers: headers);
  }

  /// POST genérico con auto-retry si el token expiró
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    var headers = await _getHeaders(withAuth: withAuth);
    var response = await http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: headers,
      body: jsonEncode(body),
    );

    if (withAuth && response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _getHeaders(withAuth: true);
        response = await http.post(
          Uri.parse("$baseUrl$endpoint"),
          headers: headers,
          body: jsonEncode(body),
        );
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
    final response = await http.get(
      Uri.parse('$baseUrl/categorias'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final List<dynamic> data = jsonData['data'];

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
      throw Exception('Error al obtener categorías');
    }
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
        headers: {"Content-Type": "application/json"},
      );

      // ✅ 4. Validar estado de la respuesta
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final List<dynamic> data = decoded['data'];
          return List<Map<String, dynamic>>.from(data);
        } else if (decoded is List) {
          // En caso de que el backend devuelva una lista directa
          return List<Map<String, dynamic>>.from(decoded);
        } else {
          return [];
        }
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
    final response = await http.get(
      Uri.parse('$baseUrl/paises'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // ⚠️ Algunos endpoints devuelven {"success": true, "data": [...]}
      // otros solo una lista. Manejamos ambos casos.
      final List<dynamic> data = (jsonData.containsKey('data'))
          ? jsonData['data']
          : jsonData;

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
      throw Exception('Error al obtener países (HTTP ${response.statusCode})');
    }
  }

  // ✅ Obtener departamentos por país (usa el id del país)
  static Future<List<Map<String, dynamic>>> getDepartamentosPorPais(
    int paisId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/departamentos/$paisId'),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      final List<dynamic> data = (jsonData.containsKey('data'))
          ? jsonData['data']
          : jsonData;

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
      throw Exception(
        'Error al obtener departamentos (HTTP ${response.statusCode})',
      );
    }
  }

  // --- Obtener Departamentos por país ---
  static Future<List<Map<String, dynamic>>> getDepartamentos({
    required int paisId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/departamentos/$paisId'),
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
      throw Exception(
        '❌ Error al obtener departamentos (${response.statusCode}).',
      );
    }
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

/////////////////////////// Loterias ////////////////////////////

  /// 📋 Listar loterías disponibles
static Future<List<dynamic>> getLoteriasPorPais(String paisId) async {
  final response = await http.get(
    Uri.parse("$baseUrl/loterias?pais_id=$paisId"),
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
}
