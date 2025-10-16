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
    T? _first<T>(List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) {
          return m[k] as T;
        }
      }
      return null;
    }

    DateTime _parseFecha(Object? raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      final s = raw.toString();
      if (s.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(s);
      } catch (_) {
        // Si viene 'YYYY-MM-DD', DateTime.parse lo soporta. Si no, fallback a hoy.
        return DateTime.now();
      }
    }

    double _toDouble(Object? raw) {
      if (raw == null) return 0.0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? 0.0;
    }

    String _nombreCliente() {
      final raw = _first<String>(['clienteNombre', 'cliente_nombre', 'cliente']);
      if (raw == null || raw.trim().isEmpty) return '—';
      return raw.trim();
    }

    final fecha = _parseFecha(
      _first<Object>(['fecha', 'fecha_pago', 'created_at', 'fechaPago']),
    );

    return PagoVista(
      clienteNombre: _nombreCliente(),
      prestamoId: _first<num>(['prestamoId', 'prestamo_id'])?.toInt(),
      fecha: fecha,
      monto: _toDouble(_first<Object>(['monto', 'total', 'total_monto'])),
      nota: _first<String>(['nota', 'comentario']),
    );
  }
}
