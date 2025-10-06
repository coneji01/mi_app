// lib/data/db_service_ext.dart
import 'package:sqflite/sqflite.dart';

import 'db_service.dart';
import '../models/prestamo.dart';

extension PrestamosDbExt on DbService {
  // ========================= SCHEMA =========================

  Future<void> _ensurePrestamosSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prestamos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        balance_pendiente REAL NOT NULL,
        total_a_pagar REAL NOT NULL,
        cuotas_totales INTEGER NOT NULL,
        cuotas_pagadas INTEGER NOT NULL DEFAULT 0,
        interes REAL NOT NULL,                 -- <- tu modelo usa "interes"
        modalidad TEXT NOT NULL,
        tipo_amortizacion TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        proximo_pago TEXT,
        FOREIGN KEY(cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pagos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamo_id INTEGER NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        nota TEXT,
        tipo TEXT NOT NULL,                    -- 'cuota' | 'abono' | etc.
        FOREIGN KEY(prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_prestamo ON pagos(prestamo_id);');
  }

  // ======================= PRÉSTAMOS ========================

  Future<int> crearPrestamo(Prestamo p) async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    return db.insert('prestamos', {
      'cliente_id': p.clienteId,
      'monto': p.monto,
      'balance_pendiente': p.balancePendiente,
      'total_a_pagar': p.totalAPagar,
      'cuotas_totales': p.cuotasTotales,
      'cuotas_pagadas': p.cuotasPagadas,
      'interes': p.interes, // 👈 importante
      'modalidad': p.modalidad,
      'tipo_amortizacion': p.tipoAmortizacion,
      'fecha_inicio': p.fechaInicio,
      'proximo_pago': p.proximoPago,
    });
  }

  Future<Prestamo?> getPrestamoById(int id) async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    final rows = await db.query('prestamos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final m = rows.first;

    return Prestamo(
      id: m['id'] as int,
      clienteId: m['cliente_id'] as int,
      monto: (m['monto'] as num).toDouble(),
      balancePendiente: (m['balance_pendiente'] as num).toDouble(),
      totalAPagar: (m['total_a_pagar'] as num).toDouble(),
      cuotasTotales: m['cuotas_totales'] as int,
      cuotasPagadas: m['cuotas_pagadas'] as int,
      interes: (m['interes'] as num).toDouble(),            // 👈 importante
      modalidad: m['modalidad'] as String,
      tipoAmortizacion: m['tipo_amortizacion'] as String,
      fechaInicio: m['fecha_inicio'] as String,
      proximoPago: m['proximo_pago'] as String?,
    );
  }

  /// Para listas con nombre del cliente (lo usa tu pantalla de préstamos)
  Future<List<Map<String, dynamic>>> listarPrestamosConCliente() async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    return db.rawQuery('''
      SELECT
        p.id,
        p.cliente_id,
        p.monto,
        p.balance_pendiente,
        p.total_a_pagar,
        p.cuotas_totales,
        p.cuotas_pagadas,
        p.interes,
        p.modalidad,
        p.tipo_amortizacion,
        p.fecha_inicio,
        p.proximo_pago,
        (c.nombre || ' ' || c.apellido) AS cliente
      FROM prestamos p
      JOIN clientes c ON c.id = p.cliente_id
      ORDER BY p.id DESC;
    ''');
  }

  // ========================= PAGOS =========================

  Future<List<Map<String, dynamic>>> listarPagosDePrestamo(int prestamoId) async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    // No tenemos 'vence' en la tabla pagos; tu UI ya lo maneja como '-'
    return db.query(
      'pagos',
      where: 'prestamo_id = ?',
      whereArgs: [prestamoId],
      orderBy: 'fecha DESC, id DESC',
    );
  }

  Future<int> agregarPagoRapido({
    required int prestamoId,
    required double monto,
    String? nota,
    required String tipo,
    DateTime? fecha,
  }) async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    return db.transaction<int>((txn) async {
      final pRows = await txn.query('prestamos', where: 'id = ?', whereArgs: [prestamoId], limit: 1);
      if (pRows.isEmpty) throw Exception('Préstamo no encontrado');

      final p = pRows.first;
      double balance = (p['balance_pendiente'] as num).toDouble();
      final double totalAPagar = (p['total_a_pagar'] as num).toDouble();
      final int cuotasTotales = p['cuotas_totales'] as int;
      int cuotasPagadas = p['cuotas_pagadas'] as int;
      final String modalidad = (p['modalidad'] as String).toLowerCase();
      final String? proximoRaw = p['proximo_pago'] as String?;
      DateTime base = proximoRaw != null ? (DateTime.tryParse(proximoRaw) ?? DateTime.now()) : DateTime.now();

      // 1) Insertar pago
      final pagoId = await txn.insert('pagos', {
        'prestamo_id': prestamoId,
        'monto': monto,
        'fecha': (fecha ?? DateTime.now()).toIso8601String(),
        'nota': nota,
        'tipo': tipo,
      });

      // 2) Actualizar balance
      balance = (balance - monto).clamp(0.0, double.infinity);

      // 3) Si es pago por cuota, calcular cuántas cuotas equivalen
      if (tipo.toLowerCase() == 'cuota' && cuotasTotales > 0) {
        final double valorCuota = totalAPagar / cuotasTotales;
        final int pagadas = (monto / valorCuota).floor();
        if (pagadas > 0) {
          cuotasPagadas = (cuotasPagadas + pagadas).clamp(0, cuotasTotales);
        }
      }

      // 4) Próximo pago
      DateTime? proximo;
      if (cuotasPagadas >= cuotasTotales || balance <= 0.0) {
        proximo = null;
      } else {
        if (modalidad.contains('diario')) {
          proximo = base.add(const Duration(days: 1));
        } else if (modalidad.contains('interdiario')) {
          proximo = base.add(const Duration(days: 2));
        } else if (modalidad.contains('seman')) {
          proximo = base.add(const Duration(days: 7));
        } else if (modalidad.contains('quinc')) {
          proximo = base.add(const Duration(days: 15));
        } else if (modalidad.contains('mens')) {
          proximo = DateTime(base.year, base.month + 1, base.day);
        } else if (modalidad.contains('biseman')) {
          proximo = base.add(const Duration(days: 14));
        } else {
          proximo = base.add(const Duration(days: 30));
        }
      }

      await txn.update(
        'prestamos',
        {
          'balance_pendiente': balance,
          'cuotas_pagadas': cuotasPagadas,
          'proximo_pago': proximo?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );

      return pagoId;
    });
  }

  /// Lo que tu pantalla necesita: devolver **el Préstamo actualizado**.
  Future<Prestamo> registrarPagoCuotas({
    required int prestamoId,
    required int cuotas,
    required double capital,
    required double interes,
    required double total,
    required DateTime fecha,
    required DateTime? vence,
    required DateTime? proximoPago,
  }) async {
    final db = await database;
    await _ensurePrestamosSchema(db);

    return db.transaction<Prestamo>((txn) async {
      final pRows = await txn.query('prestamos', where: 'id = ?', whereArgs: [prestamoId], limit: 1);
      if (pRows.isEmpty) {
        throw Exception('Préstamo no encontrado');
      }
      final p = pRows.first;

      // 1) Registrar el pago (nota informativa)
      await txn.insert('pagos', {
        'prestamo_id': prestamoId,
        'monto': total, // capital + interes de N cuotas
        'fecha': fecha.toIso8601String(),
        'nota': 'Pago de $cuotas cuota(s). Capital: $capital, Interés: $interes',
        'tipo': 'cuota',
      });

      // 2) Actualizar préstamo
      final double balanceAnterior = (p['balance_pendiente'] as num).toDouble();
      final int cuotasTotales = p['cuotas_totales'] as int;
      final int cuotasPagadasPrev = p['cuotas_pagadas'] as int;

      final double balanceNuevo = (balanceAnterior - capital).clamp(0.0, double.infinity);
      final int cuotasPagadasNueva = (cuotasPagadasPrev + cuotas).clamp(0, cuotasTotales);

      await txn.update(
        'prestamos',
        {
          'balance_pendiente': balanceNuevo,
          'cuotas_pagadas': cuotasPagadasNueva,
          'proximo_pago': proximoPago?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );

      // 3) Releer y devolver el préstamo actualizado
      final updatedRows = await txn.query('prestamos', where: 'id = ?', whereArgs: [prestamoId], limit: 1);
      final m = updatedRows.first;

      return Prestamo(
        id: m['id'] as int,
        clienteId: m['cliente_id'] as int,
        monto: (m['monto'] as num).toDouble(),
        balancePendiente: (m['balance_pendiente'] as num).toDouble(),
        totalAPagar: (m['total_a_pagar'] as num).toDouble(),
        cuotasTotales: m['cuotas_totales'] as int,
        cuotasPagadas: m['cuotas_pagadas'] as int,
        interes: (m['interes'] as num).toDouble(),
        modalidad: m['modalidad'] as String,
        tipoAmortizacion: m['tipo_amortizacion'] as String,
        fechaInicio: m['fecha_inicio'] as String,
        proximoPago: m['proximo_pago'] as String?,
      );
    });
  }
}
