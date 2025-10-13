// lib/data/db_service_ext.dart
import 'package:sqflite/sqflite.dart';
import 'db_service.dart';

extension PrestamosDbExt on DbService {
  Future<List<Map<String, dynamic>>> getPrestamosByCliente(int clienteId) async {
    final Database db = await DbService.instance.database;

    const sql = '''
      SELECT
        p.id             AS id,
        p.clienteId      AS clienteId,
        p.monto          AS monto,
        p.interes        AS interes,
        p.modalidad      AS modalidad,
        p.fechaInicio    AS fechaInicio,
        p.cuotasTotales  AS cuotasTotales
      FROM prestamos p
      WHERE p.clienteId = ?
      ORDER BY p.id DESC
    ''';

    return db.rawQuery(sql, [clienteId]);
  }
}
