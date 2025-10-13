// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP alineado a tu Swagger + helpers de autenticación.
/// Rutas base que asume (ajústalas si tu backend difiere):
///   GET  /                       -> ping
///   POST /auth/register          -> { ... }
///   POST /auth/login             -> { access_token|token, ... }
///   GET  /clientes
///   POST /clientes
///   PUT  /clientes/{cid}
///   DELETE /clientes/{cid}
///   GET  /prestamos
///   POST /prestamos
///   PUT  /prestamos/{pid}
///   DELETE /prestamos/{pid}
///   GET  /prestamos/{pid}/pagos
///   POST /pagos
class ApiClient {
  ApiClient(String base, {String? token})
      : baseUrl = base.replaceAll(RegExp(r'/+$'), ''),
        _token = token;

  /// URL base **sin** barra final. Ej: http://190.93.188.250:8081
  final String baseUrl;

  String? _token;

  /// Establece o elimina el token Bearer.
  void setToken(String? token) => _token = (token == null || token.isEmpty) ? null : token;

  /// Indica si hay token cargado.
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  // ----------------- Utils -----------------
  dynamic _decode(http.Response r) {
    if (r.body.isEmpty) return null;
    try {
      return jsonDecode(r.body);
    } catch (_) {
      return r.body; // devuelve texto si no es JSON válido
    }
  }

  Never _throwHttp(String where, http.Response r) {
    final body = r.body.isEmpty ? '' : r.body;
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw Exception('$where: ${r.statusCode} (No autenticado) $body');
    }
    throw Exception('$where: ${r.statusCode} $body');
  }

  // ----------------- Ping -----------------
  Future<bool> ping() async {
    final r = await http.get(_u('/'));
    return r.statusCode >= 200 && r.statusCode < 300;
  }

  // ----------------- Auth -----------------
  /// Registro básico. Devuelve el JSON que responda tu backend.
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final r = await http.post(_u('/auth/register'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('register', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  /// Login; intenta extraer el token con claves comunes. Guarda el token en memoria.
  /// Devuelve el JSON de respuesta para que el UI pueda usar otros campos si quiere.
  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final body = {
      'username': usernameOrEmail,
      'email': usernameOrEmail,
      'password': password,
    };
    final r = await http.post(_u('/auth/login'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('login', r);

    final Map<String, dynamic> data = Map<String, dynamic>.from(_decode(r) ?? {});
    final token = _pickToken(data);
    if (token != null && token.isNotEmpty) {
      setToken(token);
    }
    return data;
  }

  /// Limpia el token en memoria (no llama endpoint).
  void logout() => setToken(null);

  /// Intenta encontrar un token en el JSON (access_token, token, data.token, etc.)
  String? _pickToken(Map<String, dynamic> json) {
    if (json['access_token'] is String) return json['access_token'] as String;
    if (json['token'] is String) return json['token'] as String;
    final data = json['data'];
    if (data is Map && data['token'] is String) return data['token'] as String;
    return null;
  }

  // ================== Clientes ==================
  Future<List<dynamic>> listClientes({String? search}) async {
    final uri = (search == null || search.isEmpty)
        ? _u('/clientes')
        : _u('/clientes?search=${Uri.encodeQueryComponent(search)}');

    final r = await http.get(uri, headers: _headers);
    if (r.statusCode != 200) _throwHttp('listClientes', r);

    final data = _decode(r);
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'];
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> createCliente(Map<String, dynamic> body) async {
    final r = await http.post(_u('/clientes'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('createCliente', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> body) async {
    final r = await http.put(_u('/clientes/$id'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('updateCliente', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<void> deleteCliente(int id) async {
    final r = await http.delete(_u('/clientes/$id'), headers: _headers);
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('deleteCliente', r);
  }

  // ================== Préstamos ==================
  Future<List<dynamic>> listPrestamos() async {
    final r = await http.get(_u('/prestamos'), headers: _headers);
    if (r.statusCode != 200) _throwHttp('listPrestamos', r);

    final data = _decode(r);
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'];
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> createPrestamo(Map<String, dynamic> body) async {
    final r = await http.post(_u('/prestamos'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('createPrestamo', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<Map<String, dynamic>> updatePrestamo(int id, Map<String, dynamic> body) async {
    final r = await http.put(_u('/prestamos/$id'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('updatePrestamo', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<void> deletePrestamo(int id) async {
    final r = await http.delete(_u('/prestamos/$id'), headers: _headers);
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('deletePrestamo', r);
  }

  // ================== Pagos ==================
  Future<List<dynamic>> listPagosDePrestamo(int prestamoId) async {
    final r = await http.get(_u('/prestamos/$prestamoId/pagos'), headers: _headers);
    if (r.statusCode != 200) _throwHttp('listPagosDePrestamo', r);

    final data = _decode(r);
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'];
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> createPago(Map<String, dynamic> body) async {
    final r = await http.post(_u('/pagos'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwHttp('createPago', r);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }
}
