// lib/data/repository.dart
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/settings.dart';

/// Repositorio SOLO backend.
/// Centraliza la instancia de ApiClient y expone métodos usados por las pantallas.
class Repository with ChangeNotifier {
  Repository._();
  static final Repository i = Repository._();

  ApiClient? _api;
  String _baseUrl = '';
  String? _authToken; // bearer opcional

  /// ¿Hay URL válida e instancia de cliente?
  bool get isReady => _api != null && _baseUrl.isNotEmpty;

  /// ¿Hay token cargado?
  bool get isAuthenticated => (_authToken != null && _authToken!.isNotEmpty);

  String get baseUrl => _baseUrl;

  /// Inicializa leyendo Settings (puedes sobreescribir con parámetros).
  Future<void> init({String? baseUrl, String? authToken}) async {
    final s = Settings.instance;
    await s.ensureInitialized();

    _baseUrl = (baseUrl ?? s.backendUrl).trim().replaceAll(RegExp(r'/+$'), '');
    _authToken = (authToken ?? s.authToken)?.trim();

    if (_baseUrl.isEmpty) {
      _api = null;
      notifyListeners();
      return;
    }
    _api = ApiClient(_baseUrl, token: _authToken);
    notifyListeners();
  }

  /// Cambia la URL base en caliente (lo usa ConfiguracionScreen).
  void setBaseUrl(String url) {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = cleaned;
    if (cleaned.isEmpty) {
      _api = null;
    } else {
      _api = ApiClient(cleaned, token: _authToken);
    }
    notifyListeners();
  }

  /// Establece (o borra) el token y lo persiste en Settings.
  Future<void> setAuthToken(String? token) async {
    final t = (token == null || token.isEmpty) ? null : token.trim();
    _authToken = t;
    _api?.setToken(t);
    await Settings.instance.setAuthToken(t ?? '');
    notifyListeners();
  }

  /// Prueba rápida de conexión (GET /). Devuelve true si 200..299.
  Future<bool> probarConexion() async {
    if (_api == null) return false;
    return _api!.ping();
  }

  // ================== Auth ==================

  /// Registro simple; devuelve el JSON del backend.
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    _ensureReady();
    final res = await _api!.register(body);
    return Map<String, dynamic>.from(res);
  }

  /// Login; extrae token de la respuesta y lo guarda.
  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _ensureReady();
    final res = await _api!.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );

    // Intenta recoger token para persistirlo.
    final token = (res['access_token'] ??
        res['token'] ??
        (res['data'] is Map ? res['data']['token'] : null));
    if (token is String && token.isNotEmpty) {
      await setAuthToken(token);
    }
    return Map<String, dynamic>.from(res);
  }

  /// Elimina el token en memoria y en Settings.
  Future<void> logout() => setAuthToken(null);

  // ================== Endpoints usados por la app ==================

  // ---- Clientes ----
  Future<List<Map<String, dynamic>>> clientes({String? search}) async {
    _ensureReady();
    final l = await _api!.listClientes(search: search);
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---- Préstamos ----
  Future<List<Map<String, dynamic>>> prestamos() async {
    _ensureReady();
    final l = await _api!.listPrestamos();
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> crearPrestamo(Map<String, dynamic> body) async {
    _ensureReady();
    final m = await _api!.createPrestamo(body);
    return Map<String, dynamic>.from(m);
  }

  // ---- Pagos ----
  Future<Map<String, dynamic>> crearPago(Map<String, dynamic> body) async {
    _ensureReady();
    final m = await _api!.createPago(body);
    return Map<String, dynamic>.from(m);
  }

  // ----------------- Helpers -----------------
  void _ensureReady() {
    if (_api == null) {
      throw StateError(
        'Repository no inicializado. Configura la URL del backend en Configuración.',
      );
    }
  }
}
