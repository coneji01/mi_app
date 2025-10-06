import 'package:sqflite/sqflite.dart';
import '../data/db_service.dart';

/// Servicio de reportes y utilidades sobre pagos.
/// Compatible con el esquema actual:
/// pagos(id, prestamoId, monto, fecha, nota)
class PagosService {
  PagosService();

  final _dbService = DbService.instance;

  /// Extrae el tipo desde la nota con formato "[tipo] texto..."
  /// Si no hay marcador, devuelve 'otros'.
  String _tipoFromNota(Object? nota) {
    final s = (nota as String?)?.trim() ?? '';
    final m = RegExp(r'\[([a-zA-ZáéíóúÁÉÍÓÚñÑ]+)\]').firstMatch(s);
    return (m?.group(1)?.toLowerCase() ?? 'otros');
  }

  /// Lista los pagos de un mes (más recientes primero).
  Future<List<PagoItem>> pagosDelMes(DateTime month) async {
    final Database db = await _dbService.database;
    final inicio = DateTime(month.year, month.month, 1);
    final fin = DateTime(month.year, month.month + 1, 1);

    try {
      final res = await db.query(
        'pagos',
        where: 'fecha >= ? AND fecha < ?',
        whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
        orderBy: 'fecha DESC, id DESC',
      );
      return res.map((e) => PagoItem.fromMap(e, _tipoFromNota(e['nota']))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Totales por mes del año, separados por tipo.
  /// Tipos: Capital / Interés / Mora / Seguro / Otros / Gastos
  /// (el tipo se toma de la nota: "[capital] mi nota")
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
    final inicio = DateTime(year, 1, 1);
    final fin = DateTime(year + 1, 1, 1);

    try {
      // Traemos lo necesario y agregamos en memoria por tipo/mes
      final rows = await db.query(
        'pagos',
        columns: ['fecha', 'monto', 'nota'],
        where: 'fecha >= ? AND fecha < ?',
        whereArgs: [inicio.toIso8601String(), fin.toIso8601String()],
        orderBy: 'fecha ASC',
      );

      for (final r in rows) {
        final fecha = DateTime.tryParse(r['fecha'] as String? ?? '');
        if (fecha == null) continue;
        final idx = (fecha.month - 1).clamp(0, 11);
        final total = (r['monto'] as num?)?.toDouble() ?? 0.0;
        final tipo = _tipoFromNota(r['nota']);

        switch (tipo) {
          case 'capital':
            out['Capital']![idx] += total;
            break;
          case 'interes':
          case 'interés':
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
    } catch (_) {
      // swallow: devolvemos lo acumulado (cero)
    }
    return out;
  }

  /// Inserta un pago: usa el método de dominio que ya actualiza balance
  /// cuando el `tipo` es 'capital'. El `prestamoId` debe existir.
  Future<void> insertPago({
    required DateTime fecha,
    required double monto,
    required String tipo,      // 'capital','interes','mora','seguro','gastos','otros'
    String? comentario,
    required int prestamoId,
  }) async {
    // Reutilizamos la lógica centralizada: agrega pago y
    // si es a capital, descuenta del balance.
    await _dbService.agregarPagoRapido(
      prestamoId: prestamoId,
      monto: monto,
      nota: comentario,
      tipo: tipo,
    );
  }
}

/// DTO ligero para listar pagos
class PagoItem {
  final int? id;
  final DateTime fecha;
  final double monto;
  final String tipo;      // derivado de nota
  final String? cliente;  // opcional si quieres enriquecer con JOIN

  PagoItem({
    required this.id,
    required this.fecha,
    required this.monto,
    required this.tipo,
    this.cliente,
  });

  /// `tipoDerivado` viene de PagosService._tipoFromNota(map['nota'])
  factory PagoItem.fromMap(Map<String, Object?> map, String tipoDerivado) {
    return PagoItem(
      id: map['id'] as int?,
      fecha: DateTime.parse((map['fecha'] as String?) ?? DateTime.now().toIso8601String()),
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      tipo: tipoDerivado,
      // `cliente` no existe en la tabla pagos actual; déjalo null o
      // agrega un JOIN si decides enriquecerlo.
      cliente: null,
    );
  }
}
