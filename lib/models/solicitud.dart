// lib/models/solicitud.dart
class Solicitud {
  final int? id;
  final String leadId; // identificador único de la solicitud
  final String? nombre; // opcional
  final String? telefono; // e.g. 8091234567
  final String estado; // enviada | recibida | cancelada (libre)
  final String urlFormulario; // link compartible
  final DateTime creadoEn;

  Solicitud({
    this.id,
    required this.leadId,
    this.nombre,
    this.telefono,
    required this.estado,
    required this.urlFormulario,
    required this.creadoEn,
  });

  factory Solicitud.fromMap(Map<String, dynamic> m) {
    T? _first<T>(List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) {
          return m[k] as T;
        }
      }
      return null;
    }

    DateTime _parseDateTime(Object? raw) {
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      final s = raw.toString().trim();
      if (s.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    String? _string(List<String> keys) => _first<String>(keys)?.trim();

    final id = _first<num>(['id', 'solicitudId', 'solicitud_id'])?.toInt();
    final lead = _string(['leadId', 'lead_id', 'lead', 'codigo']) ?? '';
    final estado = _string(['estado', 'status']) ?? 'enviada';
    final url = _string(['urlFormulario', 'url_formulario', 'url']) ?? '';
    final creado = _parseDateTime(
      _first<Object>(['creadoEn', 'creado_en', 'created_at', 'createdAt']),
    );

    return Solicitud(
      id: id,
      leadId: lead,
      nombre: _string(['nombre']),
      telefono: _string(['telefono', 'telefono_contacto', 'phone']),
      estado: estado,
      urlFormulario: url,
      creadoEn: creado,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'leadId': leadId,
        'nombre': nombre,
        'telefono': telefono,
        'estado': estado,
        'urlFormulario': urlFormulario,
        'creadoEn': creadoEn.toIso8601String(),
      };
}
