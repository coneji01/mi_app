// lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Excepción HTTP propia compatible con Web (sin dart:io).
class ApiHttpException implements Exception {
  final int statusCode;
  final String body;
  ApiHttpException(this.statusCode, this.body);
  @override
  String toString() => 'HTTP $statusCode: $body';
}

/// Cliente HTTP para tu backend FastAPI.
/// baseUrl: sin barra final, p.ej. http://190.93.188.250:8081
class ApiClient {
  ApiClient(String baseUrl, {String? token})
      : _baseUrl = _normalizeBase(baseUrl),
        _client = http.Client(),
        _token = token {
    _baseUri = Uri.parse(_baseUrl.isEmpty ? '/' : _baseUrl);
  }

  final http.Client _client;
  final String _baseUrl;
  late final Uri _baseUri;
  String? _token;

  static String _normalizeBase(String v) => v.trim().replaceAll(RegExp(r'/+$'), '');

  void setToken(String? token) => _token = token;

  Uri _resolve(String path, [Map<String, dynamic>? query]) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    final u = _baseUri.resolve(p);
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: {
      ...u.queryParameters,
      for (final e in query.entries) e.key: '${e.value}',
    });
  }

  Map<String, String> _headersJson() => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> _headersForm() => {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return json.decode(body);
    } catch (_) {
      return body;
    }
  }

  dynamic _okOrThrow(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return _decode(r.body);
    }
    throw ApiHttpException(r.statusCode, r.body.isEmpty ? (r.reasonPhrase ?? '') : r.body);
  }

  Future<T> _wrap<T>(Future<http.Response> f) async {
    try {
      final r = await f.timeout(const Duration(seconds: 20));
      final decoded = _okOrThrow(r);
      return decoded as T;
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado');
    } on http.ClientException catch (e) {
      throw Exception('No se pudo conectar (${e.message}). Revisa URL y CORS.');
    }
  }

  // ========= Root / ping =========
  Future<Map<String, dynamic>?> ping() async {
    final res = await _wrap<dynamic>(_client.get(_resolve('/'), headers: _headersJson()));
    return res is Map ? Map<String, dynamic>.from(res) : null;
  }

  // ========= Auth =========
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.post(_resolve('/auth/register'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final res = await _wrap<dynamic>(
      _client.post(
        _resolve('/auth/login'),
        headers: _headersForm(),
        body: {'username': usernameOrEmail, 'password': password},
      ),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  // ========= Clientes =========
  Future<List<dynamic>> listClientes({String? search}) async {
    final res = await _wrap<dynamic>(_client.get(
      _resolve('/clientes', {if (search != null && search.trim().isNotEmpty) 'search': search.trim()}),
      headers: _headersJson(),
    ));
    return List<dynamic>.from(res as List);
  }

  Future<Map<String, dynamic>> createCliente(Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.post(_resolve('/clientes'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.put(_resolve('/clientes/$id'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deleteCliente(int id) async {
    await _wrap<dynamic>(_client.delete(_resolve('/clientes/$id'), headers: _headersJson()));
  }

  // ========= Préstamos =========
  Future<List<dynamic>> listPrestamos() async {
    final res = await _wrap<dynamic>(_client.get(_resolve('/prestamos'), headers: _headersJson()));
    return List<dynamic>.from(res as List);
  }

  Future<Map<String, dynamic>?> getPrestamo(int id) async {
    try {
      final res = await _wrap<dynamic>(_client.get(_resolve('/prestamos/$id'), headers: _headersJson()));
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPrestamo(Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.post(_resolve('/prestamos'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updatePrestamo(int id, Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.put(_resolve('/prestamos/$id'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deletePrestamo(int id) async {
    await _wrap<dynamic>(_client.delete(_resolve('/prestamos/$id'), headers: _headersJson()));
  }

  // ========= Pagos =========
  Future<List<dynamic>> listPagosDePrestamo(int prestamoId) async {
    try {
      final res = await _wrap<dynamic>(
        _client.get(_resolve('/prestamos/$prestamoId/pagos'), headers: _headersJson()),
      );
      return List<dynamic>.from(res as List);
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPago(Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.post(_resolve('/pagos'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deletePago(int id) async {
    await _wrap<dynamic>(_client.delete(_resolve('/pagos/$id'), headers: _headersJson()));
  }

  /// ⚠️ Estos dos sólo sirven si implementas esos endpoints en el backend.
  Future<List<dynamic>> listPagosResumen({bool detalle = false}) async {
    final res = await _wrap<dynamic>(
      _client.get(_resolve('/pagos/resumen', {if (detalle) 'detalle': '1'}), headers: _headersJson()),
    );
    return List<dynamic>.from(res as List);
  }

  Future<List<dynamic>> listPrestamosDeCliente(int clienteId) async {
    final res = await _wrap<dynamic>(
      _client.get(_resolve('/clientes/$clienteId/prestamos'), headers: _headersJson()),
    );
    return List<dynamic>.from(res as List);
  }

  // ========= Solicitudes =========
  Future<List<dynamic>> listSolicitudes() async {
    final res = await _wrap<dynamic>(
      _client.get(_resolve('/solicitudes'), headers: _headersJson()),
    );
    return List<dynamic>.from(res as List);
  }

  Future<Map<String, dynamic>> createSolicitud(Map<String, dynamic> body) async {
    final res = await _wrap<dynamic>(
      _client.post(_resolve('/solicitudes'), headers: _headersJson(), body: json.encode(body)),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  // ========= Dashboard =========
  Future<Map<String, dynamic>> dashboard({required int year, required int month}) async {
    final res = await _wrap<dynamic>(
      _client.get(_resolve('/dashboard', {'year': year, 'month': month}), headers: _headersJson()),
    );
    return Map<String, dynamic>.from(res as Map);
  }

  void close() => _client.close();
}
