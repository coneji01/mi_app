class PagoVista {
  final int pagoId;
  final int prestamoId;
  final int? clienteId;
  final String clienteNombre;
  final double monto;
  final DateTime fecha;
  final String? nota;

  PagoVista({
    required this.pagoId,
    required this.prestamoId,
    required this.clienteId,
    required this.clienteNombre,
    required this.monto,
    required this.fecha,
    this.nota,
  });

  static DateTime _parseFecha(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final s = v.toString();
    // Acepta ISO-8601 u “YYYY-MM-DD …”
    return DateTime.tryParse(s) ??
        DateTime.tryParse(s.split(' ').first) ??
        DateTime.now();
  }

  factory PagoVista.fromMap(Map<String, Object?> m) {
    return PagoVista(
      pagoId: (m['pagoId'] as num).toInt(),
      prestamoId: (m['prestamoId'] as num).toInt(),
      clienteId: (m['clienteId'] as num?)?.toInt(),
      clienteNombre: (m['clienteNombre'] as String?)?.trim().isNotEmpty == true
          ? (m['clienteNombre'] as String).trim()
          : 'Cliente',
      monto: (m['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: _parseFecha(m['fecha']),
      nota: m['nota'] as String?,
    );
  }
}
