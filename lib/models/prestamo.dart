// lib/models/prestamo.dart

class Prestamo {
  final int? id;
  final int clienteId;

  // Monetarios / métricas
  final double monto;
  final double? balancePendiente;
  final double? totalAPagar;

  // Cuotas
  final int cuotasTotales;
  final int? cuotasPagadas;

  // Condiciones
  final double interes;          // p.ej. 0.10 = 10% por periodo
  final String modalidad;        // Semanal/Quincenal/Mensual
  final String tipoAmort;        // Francés, Interés Fijo, etc.

  // ⛳ Compatibilidad con UI antigua (p.tipoAmortizacion)
  String get tipoAmortizacion => tipoAmort;

  // Fechas/estado
  final DateTime fechaInicio;
  final DateTime? proximoPago;
  final String? estado;          // 'activo' | 'saldado' | ...
  final DateTime? creadoEn;      // solo lectura desde backend

  const Prestamo({
    this.id,
    required this.clienteId,
    required this.monto,
    this.balancePendiente,
    this.totalAPagar,
    required this.cuotasTotales,
    this.cuotasPagadas,
    required this.interes,
    required this.modalidad,
    required this.tipoAmort,
    required this.fechaInicio,
    this.proximoPago,
    this.estado,
    this.creadoEn,
  });

  // ---------------- copyWith ----------------
  Prestamo copyWith({
    int? id,
    int? clienteId,
    double? monto,
    double? balancePendiente,
    double? totalAPagar,
    int? cuotasTotales,
    int? cuotasPagadas,
    double? interes,
    String? modalidad,
    String? tipoAmort,
    DateTime? fechaInicio,
    DateTime? proximoPago,
    String? estado,
    DateTime? creadoEn,
  }) {
    return Prestamo(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      monto: monto ?? this.monto,
      balancePendiente: balancePendiente ?? this.balancePendiente,
      totalAPagar: totalAPagar ?? this.totalAPagar,
      cuotasTotales: cuotasTotales ?? this.cuotasTotales,
      cuotasPagadas: cuotasPagadas ?? this.cuotasPagadas,
      interes: interes ?? this.interes,
      modalidad: modalidad ?? this.modalidad,
      tipoAmort: tipoAmort ?? this.tipoAmort,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      proximoPago: proximoPago ?? this.proximoPago,
      estado: estado ?? this.estado,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  // ---------------- fromJson ----------------
  /// Alineado con el backend (snake_case). Admite alias `prestamoId`.
  factory Prestamo.fromJson(Map<String, dynamic> j) {
    final anyId = j.containsKey('id') ? j['id'] : j['prestamoId'];
    return Prestamo(
      id: _toInt(anyId),
      clienteId: _toInt(j['cliente_id']) ?? _toInt(j['clienteId'])!,
      monto: _toDouble(j['monto']) ?? 0.0,
      balancePendiente: _toDouble(j['balance_pendiente'] ?? j['balancePendiente']),
      totalAPagar: _toDouble(j['total_a_pagar'] ?? j['totalAPagar']),
      cuotasTotales: _toInt(j['cuotas_totales'] ?? j['cuotasTotales']) ?? 0,
      cuotasPagadas: _toInt(j['cuotas_pagadas'] ?? j['cuotasPagadas']),
      interes: _toDouble(j['interes']) ?? 0.0,
      modalidad: (j['modalidad'] ?? j['modalidad']).toString(),
      tipoAmort: (j['tipo_amort'] ?? j['tipoAmortizacion'] ?? j['tipo_amortizacion'] ?? 'Interes Fijo').toString(),
      fechaInicio: _parseDate(j['fecha_inicio'] ?? j['fechaInicio']) ?? DateTime.now(),
      proximoPago: _parseDate(j['proximo_pago'] ?? j['proximoPago']),
      estado: (j['estado'] as String?) ?? 'activo',
      creadoEn: _parseDateTime(j['creado_en']),
    );
  }

  // ---------------- toJson (completo) ----------------
  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'monto': monto,
        'balance_pendiente': balancePendiente,
        'total_a_pagar': totalAPagar,
        'cuotas_totales': cuotasTotales,
        'cuotas_pagadas': cuotasPagadas,
        'interes': interes,
        'modalidad': modalidad,
        'tipo_amort': tipoAmort,
        'fecha_inicio': _dateStr(fechaInicio),
        'proximo_pago': _dateStr(proximoPago),
        'estado': estado,
        'creado_en': _dateTimeStr(creadoEn),
      };

  /// Payload para **crear** en API (no manda `id`/`creado_en`)
  Map<String, dynamic> toCreatePayload() => {
        'cliente_id': clienteId,
        'monto': monto,
        'interes': interes,
        'modalidad': modalidad,
        'tipo_amort': tipoAmort,
        'cuotas_totales': cuotasTotales,
        'fecha_inicio': _dateStr(fechaInicio),
        // opcionales
        'balance_pendiente': balancePendiente,
        'total_a_pagar': totalAPagar,
        'cuotas_pagadas': cuotasPagadas,
        'proximo_pago': _dateStr(proximoPago),
        'estado': estado,
      }..removeWhere((k, v) => v == null);

  /// Payload para **actualizar** en API (no manda `id`/`creado_en`)
  Map<String, dynamic> toUpdatePayload() => {
        'cliente_id': clienteId,
        'monto': monto,
        'interes': interes,
        'modalidad': modalidad,
        'tipo_amort': tipoAmort,
        'cuotas_totales': cuotasTotales,
        'fecha_inicio': _dateStr(fechaInicio),
        'balance_pendiente': balancePendiente,
        'total_a_pagar': totalAPagar,
        'cuotas_pagadas': cuotasPagadas,
        'proximo_pago': _dateStr(proximoPago),
        'estado': estado,
      }..removeWhere((k, v) => v == null);

  @override
  String toString() =>
      'Prestamo(id:$id, cliente:$clienteId, monto:$monto, '
      'saldo:$balancePendiente, total:$totalAPagar, '
      'cuotas:$cuotasPagadas/$cuotasTotales, interes:$interes, '
      'modalidad:$modalidad, tipo:$tipoAmort, '
      'inicio:${_dateStr(fechaInicio)}, prox:${_dateStr(proximoPago)}, estado:$estado)';
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
    if (s.length >= 10) {
      return DateTime.parse(s.substring(0, 10));
    }
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

String? _dateStr(DateTime? d) => d == null ? null : d.toIso8601String().substring(0, 10);
String? _dateTimeStr(DateTime? d) => d?.toIso8601String();
