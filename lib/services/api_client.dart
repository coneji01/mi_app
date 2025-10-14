// lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cliente HTTP para tu backend FastAPI.
/// - En Web puedes pasar baseUrl = '' para usar mismo origen.
/// - Maneja login con x-www-form-urlencoded.
/// - Incluye timeouts y mensajes de error más claros.
class ApiClient {
  ApiClient(String baseUrl, {String? token})
      : _baseUrl = _normalizeBase(baseUrl),
        _token = token,
        _client = http.Client();

  static String _normalizeBase(String v) =>
      v.trim().replaceAll(RegExp(r'/+$'), ''); // quita trailing slash

  final http.Client _client;
  final String _baseUrl; // puede ser '' en web (rutas relativas)
  String? _token;

  void setToken(String? token) => _token = token;

  // ====== helpers ======
  Uri _u(String path, [Map<String, dynamic>? q]) {
    final p = path.startsWith('/') ? path : '/$path';
    final qp = <String, String>{};
    q?.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    // Si _baseUrl == '' => Uri relativo (ideal para Web mismo-origen)
    final full = '$_baseUrl$p';
    return Uri.parse(full).replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> _formHeaders() => {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  T _decodeOk<T>(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw HttpException('HTTP ${r.statusCode}: ${r.body}');
    }
    if (r.body.isEmpty) return (null as T);
    try {
      final decoded = json.decode(r.body);
      return decoded as T;
    } catch (_) {
      throw const FormatException('Respuesta no es JSON válido');
    }
  }

  Future<T> _wrap<T>(Future<http.Response> f) async {
    try {
      final r = await f.timeout(const Duration(seconds: 20));
      return _decodeOk<T>(r);
    } on TimeoutException {
      throw const SocketException('Tiempo de espera agotado');
    } on http.ClientException catch (e) {
      // Mensaje amigable típico de CORS/mixed-content/host inaccesible en Web
      throw Exception('No se pudo conectar (${e.message}). '
          'Verifica que el backend esté accesible y CORS habilitado.');
    } on SocketException {
      throw const SocketException('No hay conexión con el servidor');
    }
  }

  // ========== Utils ==========
  Future<Map<String, dynamic>> ping() async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.get(_u('/'), headers: _jsonHeaders()),
    );
    return r;
  }

  // ========== Auth ==========
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.post(_u('/auth/register'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.post(
        _u('/auth/login'),
        headers: _formHeaders(),
        body: {'username': usernameOrEmail, 'password': password},
      ),
    );
    return r;
  }

  // ========== Clientes ==========
  Future<List<dynamic>> listClientes({String? search}) async {
    final r = await _wrap<dynamic>(
      _client.get(
        _u('/clientes', (search == null || search.trim().isEmpty) ? null : {'search': search}),
        headers: _jsonHeaders(),
      ),
    );
    if (r is List) return r;
    throw Exception('Respuesta inesperada en /clientes');
  }

  Future<Map<String, dynamic>> createCliente(Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.post(_u('/clientes'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.put(_u('/clientes/$id'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<void> deleteCliente(int id) async {
    await _wrap<dynamic>(
      _client.delete(_u('/clientes/$id'), headers: _jsonHeaders()),
    );
  }

  // ========== Préstamos ==========
  Future<List<dynamic>> listPrestamos() async {
    final r = await _wrap<dynamic>(
      _client.get(_u('/prestamos'), headers: _jsonHeaders()),
    );
    if (r is List) return r;
    throw Exception('Respuesta inesperada en /prestamos');
  }

  Future<Map<String, dynamic>?> getPrestamo(int id) async {
    final r = await _wrap<dynamic>(
      _client.get(_u('/prestamos/$id'), headers: _jsonHeaders()),
    );
    if (r == null) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> createPrestamo(Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.post(_u('/prestamos'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<Map<String, dynamic>> updatePrestamo(int id, Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.put(_u('/prestamos/$id'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<void> deletePrestamo(int id) async {
    await _wrap<dynamic>(
      _client.delete(_u('/prestamos/$id'), headers: _jsonHeaders()),
    );
  }

  // ========== Pagos ==========
  Future<List<dynamic>> listPagosDePrestamo(int prestamoId) async {
    final r = await _wrap<dynamic>(
      _client.get(_u('/prestamos/$prestamoId/pagos'), headers: _jsonHeaders()),
    );
    if (r is List) return r;
    throw Exception('Respuesta inesperada en /prestamos/{id}/pagos');
  }

  Future<Map<String, dynamic>> createPago(Map<String, dynamic> body) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.post(_u('/pagos'), headers: _jsonHeaders(), body: json.encode(body)),
    );
    return r;
  }

  Future<void> deletePago(int id) async {
    await _wrap<dynamic>(
      _client.delete(_u('/pagos/$id'), headers: _jsonHeaders()),
    );
  }

  // ========== Dashboard ==========
  Future<Map<String, dynamic>> dashboard({required int year, required int month}) async {
    final r = await _wrap<Map<String, dynamic>>(
      _client.get(_u('/dashboard', {'year': year, 'month': month}), headers: _jsonHeaders()),
    );
    return r;
  }

  void close() => _client.close();
}
