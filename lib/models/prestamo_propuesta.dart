// lib/models/prestamo_propuesta.dart
class PrestamoPropuesta {
  final double monto;
  final double interes;            // % por período
  final int cuotas;
  final String modalidad;          // Diario / Semanal / Quincenal / Mensual...
  final String tipoAmortizacion;   // Interés Fijo / Francés / Alemán
  final double tasaPorPeriodo;     // alias de interes si lo usas así
  final String tipo;               // si ya lo usas en otras pantallas

  // NUEVOS (o consolidados): no-nulos con default para no romper nada
  final double cuota;              // cuota estimada
  final double total;              // total a pagar

  const PrestamoPropuesta({
    required this.monto,
    required this.interes,
    required this.cuotas,
    required this.modalidad,
    required this.tipoAmortizacion,
    required this.tasaPorPeriodo,
    required this.tipo,
    this.cuota = 0.0,
    this.total = 0.0,
  });

  PrestamoPropuesta copyWith({
    double? monto,
    double? interes,
    int? cuotas,
    String? modalidad,
    String? tipoAmortizacion,
    double? tasaPorPeriodo,
    String? tipo,
    double? cuota,
    double? total,
  }) {
    return PrestamoPropuesta(
      monto: monto ?? this.monto,
      interes: interes ?? this.interes,
      cuotas: cuotas ?? this.cuotas,
      modalidad: modalidad ?? this.modalidad,
      tipoAmortizacion: tipoAmortizacion ?? this.tipoAmortizacion,
      tasaPorPeriodo: tasaPorPeriodo ?? this.tasaPorPeriodo,
      tipo: tipo ?? this.tipo,
      cuota: cuota ?? this.cuota,
      total: total ?? this.total,
    );
  }
}
