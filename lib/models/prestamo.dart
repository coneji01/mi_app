class Prestamo {
  final int? id;
  final int clienteId;
  final double monto;
  final double balancePendiente;
  final double totalAPagar;        // <- requerido por DB
  final int cuotasTotales;
  final int cuotasPagadas;
  final double interes;            // tasa por periodo (%)
  final String modalidad;
  final String tipoAmortizacion;
  final String fechaInicio;        // ISO8601
  final String? proximoPago;       // <- debe ser nullable

  Prestamo({
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
    required this.fechaInicio,
    this.proximoPago,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'monto': monto,
        'balance_pendiente': balancePendiente,
        'total_a_pagar': totalAPagar,
        'cuotas_totales': cuotasTotales,
        'cuotas_pagadas': cuotasPagadas,
        'interes': interes,
        'modalidad': modalidad,
        'tipo_amortizacion': tipoAmortizacion,
        'fecha_inicio': fechaInicio,
        'proximo_pago': proximoPago,
      };

  factory Prestamo.fromMap(Map<String, dynamic> m) => Prestamo(
        id: m['id'] as int?,
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
}
