// lib/models/pago_vista.dart
class PagoVista {
  final String clienteNombre;
  final DateTime fecha;
  final double monto;
  final int? prestamoId;
  final String? nota;

  PagoVista({
    required this.clienteNombre,
    required this.fecha,
    required this.monto,
    this.prestamoId,
    this.nota,
  });

  /// Soporta:
  /// - Agrupada: clienteNombre, prestamoId, fecha('YYYY-MM-DD'), monto
  /// - Detalle:  clienteNombre, prestamoId, fecha(ISO), monto, nota
  factory PagoVista.fromMap(Map<String, dynamic> m) {
    final rawFecha = (m['fecha'] as String?) ?? DateTime.now().toIso8601String();
    final dt = DateTime.parse(rawFecha);

    return PagoVista(
      clienteNombre: (m['clienteNombre'] as String?)?.trim() ?? '—',
      prestamoId: (m['prestamoId'] as num?)?.toInt(),
      fecha: dt,
      monto: (m['monto'] as num?)?.toDouble() ?? 0.0, // tolerante a NULL
      nota: m['nota'] as String?,
    );
  }
}
