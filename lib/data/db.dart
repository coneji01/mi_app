// lib/data/db.dart
//
// Usa SIEMPRE este barrel/fachada en las pantallas:
//   import '../data/db.dart';
//
// 1) Mantiene compatibilidad (exporta lo existente).
// 2) Ofrece una API estable (Db.i.*) que no deberías romper.

export 'db_service.dart';
export 'db_service_ext.dart';

// ===== Fachada estable =====
import 'db_service.dart';
import 'db_service_ext.dart'; // trae las extensions a DbService

import '../models/cliente.dart';
import '../models/prestamo.dart';

/// Punto único para llamar la BD desde UI sin romper pantallas.
/// Migra gradualmente tus llamadas a `Db.i.metodo(...)`.
class Db {
  Db._();
  static final Db i = Db._();

  final DbService _db = DbService();

  // ---------- CLIENTES ----------
  Future<List<Cliente>> getClientes() => _db.getClientes();
  Future<int> insertCliente(Cliente c) => _db.insertCliente(c);
  Future<int> updateCliente(Cliente c) => _db.updateCliente(c);
  Future<int> deleteCliente(int id) => _db.deleteCliente(id);

  /// Normaliza cédula (solo dígitos).
  String? normalizeCedula(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }

  // ---------- PRÉSTAMOS (vía extensions sobre DbService) ----------
  Future<int> crearPrestamo(Prestamo p) => _db.crearPrestamo(p);
  Future<Prestamo?> getPrestamoById(int id) => _db.getPrestamoById(id);
  Future<List<Map<String, dynamic>>> listarPrestamosConCliente() => _db.listarPrestamosConCliente();
  Future<List<Map<String, dynamic>>> listarPagosDePrestamo(int prestamoId) => _db.listarPagosDePrestamo(prestamoId);

  Future<Prestamo> registrarPagoCuotas({
    required int prestamoId,
    required int cuotas,
    required double capital,
    required double interes,
    required double total,
    required DateTime fecha,
    required DateTime vence,
    required DateTime proximoPago,
  }) =>
      _db.registrarPagoCuotas(
        prestamoId: prestamoId,
        cuotas: cuotas,
        capital: capital,
        interes: interes,
        total: total,
        fecha: fecha,
        vence: vence,
        proximoPago: proximoPago,
      );

  Future<void> agregarPagoRapido({
    required int prestamoId,
    required double monto,
    required String tipo,
    String? nota,
  }) =>
      _db.agregarPagoRapido(
        prestamoId: prestamoId,
        monto: monto,
        tipo: tipo,
        nota: nota,
      );
}

