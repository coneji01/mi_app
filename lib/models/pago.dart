// lib/models/pago.dart

class Pago {
  final int? id;
  final int prestamoId;

  /// Fecha del movimiento (solo fecha en API)
  final DateTime fecha;

  /// Monto total del pago/movimiento
  final double monto;

  /// Extras opcionales
  final double? otros;
  final double? descuento;
  final String? nota;

  /// Categoría del movimiento:
  /// 'capital' | 'interes' | 'mora' | 'seguro' | 'otros' | 'gastos'
  final String? tipo;

  /// Campo de solo lectura desde el backend
  final DateTime? creadoEn;

  const Pago({
    this.id,
    required this.prestamoId,
    required this.fecha,
    required this.monto,
    this.otros,
    this.descuento,
    this.nota,
    this.tipo = 'capital',
    this.creadoEn,
  });

  // ---------------- copyWith ----------------
  Pago copyWith({
    int? id,
    int? prestamoId,
    DateTime? fecha,
    double? monto,
    double? otros,
    double? descuento,
    String? nota,
    String? tipo,
    DateTime? creadoEn,
  }) {
    return Pago(
      id: id ?? this.id,
      prestamoId: prestamoId ?? this.prestamoId,
      fecha: fecha ?? this.fecha,
      monto: monto ?? this.monto,
      otros: otros ?? this.otros,
      descuento: descuento ?? this.descuento,
      nota: nota ?? this.nota,
      tipo: tipo ?? this.tipo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  // ---------------- fromJson ----------------
  /// Alineado con el backend (snake_case). Admite alias `prestamoId`.
  factory Pago.fromJson(Map<String, dynamic> j) {
    return Pago(
      id: _toInt(j['id']),
      prestamoId: _toInt(j['prestamo_id'] ?? j['prestamoId'])!,
      fecha: _parseDate(j['fecha']) ?? DateTime.now(),
      monto: _toDouble(j['monto']) ?? 0.0,
      otros: _toDouble(j['otros']),
      descuento: _toDouble(j['descuento']),
      nota: (j['nota'] as String?) ?? '',
      tipo: (j['tipo'] as String?)?.toLowerCase() ?? 'capital',
      creadoEn: _parseDateTime(j['creado_en'] ?? j['creadoEn']),
    );
  }

  // ---------------- toJson (completo) ----------------
  Map<String, dynamic> toJson() => {
        'id': id,
        'prestamo_id': prestamoId,
        'fecha': _dateStr(fecha),
        'monto': monto,
        'otros': otros,
        'descuento': descuento,
        'nota': nota,
        'tipo': tipo,
        'creado_en': _dateTimeStr(creadoEn),
      };

  /// Payload para **crear** en API (no manda `id`/`creado_en`)
  Map<String, dynamic> toCreatePayload() => {
        'prestamo_id': prestamoId,
        'fecha': _dateStr(fecha),
        'monto': monto,
        'tipo': tipo,
        'otros': otros,
        'descuento': descuento,
        'nota': nota,
      }..removeWhere((k, v) => v == null);

  /// Payload para **actualizar** en API (no manda `id`/`creado_en`)
  Map<String, dynamic> toUpdatePayload() => {
        'prestamo_id': prestamoId,
        'fecha': _dateStr(fecha),
        'monto': monto,
        'tipo': tipo,
        'otros': otros,
        'descuento': descuento,
        'nota': nota,
      }..removeWhere((k, v) => v == null);

  @override
  String toString() =>
      'Pago(id:$id, prestamo:$prestamoId, fecha:${_dateStr(fecha)}, '
      'monto:$monto, tipo:$tipo, otros:$otros, desc:$descuento, nota:$nota)';
}

// ---------------- helpers ----------------
double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  try {
    // 'YYYY-MM-DD' o ISO
    if (s.length >= 10) return DateTime.parse(s.substring(0, 10));
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

DateTime? _parseDateTime(Object? v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);
String? _dateTimeStr(DateTime? d) => d?.toIso8601String();
