import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:mi_app/data/db_service.dart' as appdb; // usa tu estructura real

class PagosService {
  final _dbService = appdb.DbService();

  Future<List<PagoItem>> pagosDelMes(DateTime month) async {
    final Database db = await _dbService.database;
    final inicio = DateTime(month.year, month.month, 1);
    final fin = DateTime(month.year, month.month + 1, 1);

    try {
      final res = await db.query(
        'pagos',
        where: 'fecha >= ? AND fecha < ?',
        whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
        orderBy: 'fecha DESC',
      );
      return res.map((e) => PagoItem.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<double>>> totalesPorMesDelAnio(int year) async {
    final Map<String, List<double>> out = {
      'Capital': List.filled(12, 0),
      'Interés': List.filled(12, 0),
      'Mora': List.filled(12, 0),
      'Seguro': List.filled(12, 0),
      'Otros': List.filled(12, 0),
      'Gastos': List.filled(12, 0),
    };

    final Database db = await _dbService.database;
    try {
      final res = await db.rawQuery(
        """
        SELECT STRFTIME('%m', fecha) AS mes, tipo, SUM(monto) AS total
        FROM pagos
        WHERE STRFTIME('%Y', fecha) = ?
        GROUP BY mes, tipo
        """,
        [NumberFormat('0000').format(year)],
      );

      for (final row in res) {
        final mesStr = (row['mes'] as String?) ?? '01';
        final idx = int.parse(mesStr) - 1;
        final tipo = (row['tipo'] as String?) ?? 'otros';
        final total = (row['total'] as num?)?.toDouble() ?? 0;

        switch (tipo) {
          case 'capital':
            out['Capital']![idx] += total;
            break;
          case 'interes':
            out['Interés']![idx] += total;
            break;
          case 'mora':
            out['Mora']![idx] += total;
            break;
          case 'seguro':
            out['Seguro']![idx] += total;
            break;
          case 'gastos':
            out['Gastos']![idx] += total;
            break;
          default:
            out['Otros']![idx] += total;
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> insertPago({
    required DateTime fecha,
    required double monto,
    required String tipo,
    required String forma,
    required String caja,
    String? comentario,
    String? fotoPath,
    int? prestamoId,
    double? descuento,
    double? otros,
  }) async {
    final Database db = await _dbService.database;
    await db.insert('pagos', {
      'fecha': fecha.toIso8601String(),
      'monto': monto,
      'tipo': tipo,
      'forma': forma,
      'caja': caja,
      'comentario': comentario,
      'fotoPath': fotoPath,
      'prestamoId': prestamoId,
      'descuento': descuento ?? 0,
      'otros': otros ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class PagoItem {
  final int? id;
  final DateTime fecha;
  final double monto;
  final String? cliente;
  final String tipo;

  PagoItem({
    required this.id,
    required this.fecha,
    required this.monto,
    required this.tipo,
    this.cliente,
  });

  factory PagoItem.fromMap(Map<String, Object?> map) => PagoItem(
        id: map['id'] as int?,
        fecha: DateTime.parse(map['fecha'] as String),
        monto: (map['monto'] as num).toDouble(),
        tipo: (map['tipo'] as String?) ?? 'otros',
        cliente: map['cliente'] as String?,
      );
}

