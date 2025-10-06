// lib/data/db_service_ext.dart
import 'package:sqflite/sqflite.dart';
import 'db_service.dart';
import 'db.dart';

extension PrestamosDbExt on DbService {
  /// Lista préstamos con datos del cliente.
  /// Devuelve columnas alineadas con la UI de `prestamos_screen.dart`.
  Future<List<Map<String, dynamic>>> listarPrestamosConCliente() async {
    final Database db = await AppDatabase.instance.database;

    // NOTA:
    // - Alias p_id para el id del préstamo.
    // - c_nombre / c_apellido del cliente.
    // - Campos "de relleno" (modalidad, cuotas_totales, cuotas_pagadas,
    //   balance_pendiente, proximo_pago) se devuelven con valores neutros
    //   si tu esquema aún no los tiene. Así la pantalla no truena.
    //
    // Ajusta este SELECT cuando consolides tu esquema final.
    const sql = '''
      SELECT
        p.id                AS p_id,
        p.cliente_id        AS cliente_id,
        c.nombre            AS c_nombre,
        c.apellido          AS c_apellido,

        -- Valores por defecto seguros si no existen columnas en tu tabla:
        NULL                AS modalidad,
        0                   AS cuotas_totales,
        0                   AS cuotas_pagadas,
        0                   AS balance_pendiente,
        NULL                AS proximo_pago

      FROM prestamos p
      LEFT JOIN clientes c ON c.id = p.cliente_id
      ORDER BY p.id DESC
    ''';

    final rows = await db.rawQuery(sql);
    return rows;
  }
}
