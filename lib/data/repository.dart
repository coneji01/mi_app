// lib/data/repository.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;

import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import '../services/settings.dart';
import '../models/cliente.dart';

class Repository with ChangeNotifier {
  Repository._();
  static final Repository i = Repository._();

  ApiClient? _api;
  String _baseUrl = '';
  String? _authToken;

  bool get isReady => _api != null;
  bool get isAuthenticated => (_authToken != null && _authToken!.isNotEmpty);
  String get baseUrl => _baseUrl;

  Future<void> init({String? baseUrl, String? authToken}) async {
    final s = Settings.instance;
    await s.ensureInitialized();

    _authToken = (authToken ?? s.authToken)?.trim();

    if (kIsWeb) {
      // Web (pruebas): apunta a tu backend público
      _baseUrl = 'http://190.93.188.250:8081';
    } else {
      final fromArg = (baseUrl ?? '').trim();
      final fromSettings = s.backendUrl.trim();
      _baseUrl = (fromArg.isNotEmpty ? fromArg : fromSettings)
          .replaceAll(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && _baseUrl.isEmpty) {
      _api = null;
      notifyListeners();
      return;
    }

    _api = ApiClient(_baseUrl, token: _authToken);
    notifyListeners();
  }

  Future<void> setAuthToken(String? token) async {
    final t = (token == null || token.isEmpty) ? null : token.trim();
    _authToken = t;
    _api?.setToken(t);
    await Settings.instance.setAuthToken(t);
    notifyListeners();
  }

  // ===== Auth
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    _ensureReady();
    final res = await _api!.register(body);
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _ensureReady();
    final res = await _api!.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );
    final token = (res['access_token'] ??
        res['token'] ??
        (res['data'] is Map ? res['data']['token'] : null));
    if (token is String && token.isNotEmpty) {
      await setAuthToken(token);
    }
    return Map<String, dynamic>.from(res);
  }

  Future<void> logout() => setAuthToken(null);

  // ===== Clientes
  Future<List<Map<String, dynamic>>> clientes({String? search}) async {
    _ensureReady();
    final l = await _api!.listClientes(search: search);
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> crearCliente(
    Map<String, dynamic> body, {
    Uint8List? fotoBytes,
    String? fotoFilename,
  }) async {
    _ensureReady();
    final files = (fotoBytes != null && fotoBytes.isNotEmpty)
        ? [
            http.MultipartFile.fromBytes(
              'foto',
              fotoBytes,
              filename: fotoFilename ?? 'cliente_foto.jpg',
            ),
          ]
        : null;
    final m = await _api!.createCliente(body, files: files);
    return Map<String, dynamic>.from(m);
  }

  /// Actualizar cliente en el backend usando el modelo
  Future<Cliente> updateCliente(Cliente c) async {
    _ensureReady();
    if (c.id == null) {
      throw ArgumentError('Cliente.id es null: no se puede actualizar sin ID.');
    }
    final payload = c.toJson();
    final m = await _api!.updateCliente(c.id!, payload); // 👈 non-null
    return Cliente.fromJson(Map<String, dynamic>.from(m));
  }

  /// Versión raw por si quieres pasar un Map directo
  Future<Map<String, dynamic>> updateClienteRaw(int? id, Map<String, dynamic> body) async {
    _ensureReady();
    if (id == null) {
      throw ArgumentError('id es null: no se puede actualizar sin ID.');
    }
    final m = await _api!.updateCliente(id, body);
    return Map<String, dynamic>.from(m);
  }

  Future<void> eliminarCliente(int id) async {
    _ensureReady();
    await _api!.deleteCliente(id);
  }

  Future<void> deleteCliente(int id) => eliminarCliente(id);

  // ===== Préstamos
  Future<List<Map<String, dynamic>>> prestamos() async {
    _ensureReady();
    final l = await _api!.listPrestamos();
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> prestamoPorId(int id) async {
    _ensureReady();
    final m = await _api!.getPrestamo(id);
    if (m == null) return null;
    return Map<String, dynamic>.from(m);
  }

  Future<Map<String, dynamic>> crearPrestamo(Map<String, dynamic> body) async {
    _ensureReady();
    final m = await _api!.createPrestamo(body);
    return Map<String, dynamic>.from(m);
  }

  Future<void> eliminarPrestamo(int id) async {
    _ensureReady();
    await _api!.deletePrestamo(id);
  }

  Future<void> deletePrestamo(int id) => eliminarPrestamo(id);

  // ===== Pagos
  Future<Map<String, dynamic>> crearPagoRaw(Map<String, dynamic> body) async {
    _ensureReady();
    final m = await _api!.createPago(body);
    return Map<String, dynamic>.from(m);
  }

  Future<Map<String, dynamic>> crearPago({
    required int prestamoId,
    required String fecha,
    required double monto,
    required String tipo,
    String? nota,
    double? otros,
    double? descuento,
  }) async {
    _ensureReady();
    final body = <String, dynamic>{
      "prestamo_id": prestamoId,
      "fecha": fecha,
      "monto": monto,
      "tipo": tipo,
      if (nota != null && nota.trim().isNotEmpty) "nota": nota.trim(),
      if (otros != null) "otros": otros,
      if (descuento != null) "descuento": descuento,
    };
    final m = await _api!.createPago(body);
    return Map<String, dynamic>.from(m);
  }

  Future<List<Map<String, dynamic>>> pagosDePrestamo(int prestamoId) async {
    _ensureReady();
    final l = await _api!.listPagosDePrestamo(prestamoId);
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> eliminarPago(int id) async {
    _ensureReady();
    await _api!.deletePago(id);
  }

  Future<void> deletePago(int id) => eliminarPago(id);

  Future<List<Map<String, dynamic>>> pagosResumen({bool detalle = false}) async {
    _ensureReady();
    final l = await _api!.listPagosResumen(detalle: detalle);
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> prestamosPorCliente(int clienteId) async {
    _ensureReady();
    final l = await _api!.listPrestamosDeCliente(clienteId);
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> solicitudes() async {
    _ensureReady();
    final l = await _api!.listSolicitudes();
    return l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> crearSolicitud({
    String? nombre,
    String? telefono,
  }) async {
    _ensureReady();
    final body = <String, dynamic>{};
    if (nombre != null && nombre.trim().isNotEmpty) {
      body['nombre'] = nombre.trim();
    }
    if (telefono != null && telefono.trim().isNotEmpty) {
      body['telefono'] = telefono.trim();
    }
    final m = await _api!.createSolicitud(body);
    return Map<String, dynamic>.from(m);
  }

  // ===== Dashboard
  Future<Map<String, dynamic>> dashboard({
    required int year,
    required int month,
  }) async {
    _ensureReady();
    final res = await _api!.dashboard(year: year, month: month);
    return Map<String, dynamic>.from(res);
  }

  void _ensureReady() {
    if (_api == null) {
      throw StateError('Repository no inicializado.');
    }
  }
}
