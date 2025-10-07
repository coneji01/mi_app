// lib/models/prestamo.dart
class Prestamo {
  final int? id;
  final int clienteId;
  final double monto;
  final double balancePendiente;
  final double totalAPagar;
  final int cuotasTotales;
  final int cuotasPagadas;
  final double interes;          // % por periodo (ej. 0.10 = 10%)
  final String modalidad;        // Semanal/Quincenal/Mensual
  final String tipoAmortizacion; // Francés, Interés Fijo, etc.
  final String? fechaInicio;     // ISO-8601 (TEXT en SQLite)
  final String? proximoPago;     // ISO-8601 (TEXT en SQLite)

  const Prestamo({
    this.id,
    required this.clienteId,
    required this.monto,
    required this.balancePendiente,
    required this.totalAPagar,
    required this.cuotasTotales,
    required this.cuotasPagadas,
    required this.interes,
    required this.modalidad,
    required this.tipoAmortizacion,
    this.fechaInicio,
    this.proximoPago,
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
    String? tipoAmortizacion,
    String? fechaInicio,
    String? proximoPago,
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
      tipoAmortizacion: tipoAmortizacion ?? this.tipoAmortizacion,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      proximoPago: proximoPago ?? this.proximoPago,
    );
  }

  // ---------------- fromMap ----------------
  /// Soporta filas que traen `id` *o* alias `prestamoId` (por JOIN).
  factory Prestamo.fromMap(Map<String, dynamic> map) {
    // helpers de parseo tolerantes (int/double/string)
    int _i(v) => (v is int) ? v : int.parse(v.toString());
    double _d(v) => (v is num) ? v.toDouble() : double.parse(v.toString());
    T? _s<T>(dynamic v) => v == null ? null : v.toString() as T?;

    final anyId = map.containsKey('id') ? map['id'] : map['prestamoId'];

    return Prestamo(
      id: anyId == null ? null : _i(anyId),
      clienteId: _i(map['clienteId']),
      monto: _d(map['monto']),
      balancePendiente: _d(map['balancePendiente']),
      totalAPagar: _d(map['totalAPagar']),
      cuotasTotales: _i(map['cuotasTotales']),
      cuotasPagadas: _i(map['cuotasPagadas']),
      interes: _d(map['interes']),
      modalidad: map['modalidad']?.toString() ?? 'Mensual',
      tipoAmortizacion: map['tipoAmortizacion']?.toString() ?? 'Interés Fijo',
      fechaInicio: _s<String>(map['fechaInicio']),
      proximoPago: _s<String>(map['proximoPago']),
    );
  }

  // ---------------- toMap ----------------
  Map<String, Object?> toMap({bool includeId = false}) {
    final m = <String, Object?>{
      'clienteId'        : clienteId,
      'monto'            : monto,
      'balancePendiente' : balancePendiente,
      'totalAPagar'      : totalAPagar,
      'cuotasTotales'    : cuotasTotales,
      'cuotasPagadas'    : cuotasPagadas,
      'interes'          : interes,
      'modalidad'        : modalidad,
      'tipoAmortizacion' : tipoAmortizacion,
      'fechaInicio'      : fechaInicio,
      'proximoPago'      : proximoPago,
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  @override
  String toString() =>
      'Prestamo(id: $id, clienteId: $clienteId, monto: $monto, '
      'balancePendiente: $balancePendiente, totalAPagar: $totalAPagar, '
      'cuotas: $cuotasPagadas/$cuotasTotales, interes: $interes, '
      'modalidad: $modalidad, tipo: $tipoAmortizacion, '
      'inicio: $fechaInicio, proximo: $proximoPago)';
}
