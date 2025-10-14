// lib/data/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/prestamo.dart';
import '../models/prestamo_api_adapter.dart'; // ← usa toApiMap() / prestamoFromApiMap()

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ⛳ Ajusta a tu servidor real
  static const String _baseUrl = 'https://tu-backend.com/api';

  Future<int> crearPrestamo(Prestamo p) async {
    final url = Uri.parse('$_baseUrl/prestamos');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(p.toApiMap()), // ← nada de p.toMap()
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = jsonDecode(resp.body);
      // soporta { "id": ... } o { "data": { "id": ... } }
      final id = decoded is Map
          ? (decoded['id'] ?? (decoded['data'] is Map ? decoded['data']['id'] : null))
          : null;
      return (id is int) ? id : int.tryParse('$id') ?? 0;
    }
    throw Exception('Error al crear préstamo: ${resp.statusCode} ${resp.body}');
  }

  Future<Prestamo?> getPrestamoById(int id) async {
    final url = Uri.parse('$_baseUrl/prestamos/$id');
    final resp = await http.get(url);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      final map = decoded is Map && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      return prestamoFromApiMap(map); // ← nada de Prestamo.fromMap()
    }
    throw Exception('Error al obtener préstamo: ${resp.statusCode} ${resp.body}');
  }

  Future<void> agregarPagoRapido({
    required int prestamoId,
    required double monto,
    String? nota,
    String? tipo,
  }) async {
    final url = Uri.parse('$_baseUrl/pagos');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prestamo_id': prestamoId,
        'monto': monto,
        'nota': nota ?? '',
        'tipo': tipo ?? '',
      }),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Error al registrar pago: ${resp.statusCode} ${resp.body}');
    }
  }
}
