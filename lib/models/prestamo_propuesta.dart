// lib/models/prestamo_propuesta.dart

class PrestamoPropuesta {
  final double monto;
  final int cuotas;
  final double cuota;                 // monto de la cuota (aprox)
  final String modalidad;             // Diario / Semanal / Mensual / ...
  final String tipoAmortizacion;      // Interés Fijo / Francés / Alemán
  final double tasaPorPeriodo;        // % por período

  /// Alias usados por algunas pantallas antiguas:
  /// - `interes` ≈ `tasaPorPeriodo`
  /// - `tipo`    ≈ `tipoAmortizacion`
  final double interes;
  final String tipo;

  PrestamoPropuesta({
    required this.monto,
    required this.cuotas,
    required this.cuota,
    required this.modalidad,
    required this.tipoAmortizacion,
    required this.tasaPorPeriodo,
    double? interes,          // <-- ahora OPCIONAL
    String? tipo,             // <-- ahora OPCIONAL
  })  : interes = interes ?? tasaPorPeriodo,
        tipo = tipo ?? tipoAmortizacion;

  // (Opcionales) helpers si los necesitas
  double get totalAprox => cuota * cuotas;
}
