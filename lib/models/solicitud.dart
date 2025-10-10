// lib/models/solicitud.dart
class Solicitud {
  final int? id;
  final String leadId;        // identificador único de la solicitud
  final String? nombre;       // opcional
  final String? telefono;     // e.g. 8091234567
  final String estado;        // enviada | recibida | cancelada (libre)
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

  factory Solicitud.fromMap(Map<String, dynamic> m) => Solicitud(
        id: (m['id'] as num?)?.toInt(),
        leadId: m['leadId'] as String,
        nombre: m['nombre'] as String?,
        telefono: m['telefono'] as String?,
        estado: m['estado'] as String,
        urlFormulario: m['urlFormulario'] as String,
        creadoEn: DateTime.parse(m['creadoEn'] as String),
      );

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
