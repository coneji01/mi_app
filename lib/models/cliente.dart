/// Enum usado en varias pantallas del proyecto (detalle, edición, etc.)
enum Sexo { masculino, femenino, otro }

/// Helpers de conversión enum <-> string para base de datos
class SexoCodec {
  static String? toDb(Sexo? s) {
    if (s == null) return null;
    switch (s) {
      case Sexo.masculino:
        return 'M';
      case Sexo.femenino:
        return 'F';
      case Sexo.otro:
        return 'O';
    }
  }

  static Sexo? fromDb(String? v) {
    if (v == null) return null;
    final x = v.trim().toLowerCase();
    if (x == 'm' || x == 'masculino' || x == 'male') return Sexo.masculino;
    if (x == 'f' || x == 'femenino' || x == 'female') return Sexo.femenino;
    if (x == 'o' || x == 'otro' || x == 'other') return Sexo.otro;
    return null;
  }

  static String legible(Sexo? s) {
    switch (s) {
      case Sexo.masculino:
        return 'Masculino';
      case Sexo.femenino:
        return 'Femenino';
      case Sexo.otro:
        return 'Otro';
      default:
        return '—';
    }
  }
}

class Cliente {
  final int? id;
  final String nombre;
  final String apellido;
  final String? cedula;
  final Sexo? sexo;
  final String direccion;
  final String? telefono;
  final String creadoEn;   // ISO8601
  final String? fotoPath;

  Cliente({
    this.id,
    required this.nombre,
    required this.apellido,
    this.cedula,
    this.sexo,
    required this.direccion,
    this.telefono,
    required this.creadoEn,
    this.fotoPath,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  Cliente copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? cedula,
    Sexo? sexo,
    String? direccion,
    String? telefono,
    String? creadoEn,
    String? fotoPath,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      cedula: cedula ?? this.cedula,
      sexo: sexo ?? this.sexo,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      creadoEn: creadoEn ?? this.creadoEn,
      fotoPath: fotoPath ?? this.fotoPath,
    );
  }

  /// Lee tolerando NULL en la BD (usa '' por defecto para los `String` requeridos)
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      apellido: map['apellido'] as String? ?? '',
      cedula: map['cedula'] as String?,
      sexo: SexoCodec.fromDb(map['sexo'] as String?),
      direccion: map['direccion'] as String? ?? '',
      telefono: map['telefono'] as String?,
      creadoEn: map['creado_en'] as String? ?? '',
      fotoPath: map['foto_path'] as String?,
    );
  }

  /// Guarda usando nombres de columna en snake_case
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'cedula': cedula,
      'sexo': SexoCodec.toDb(sexo),
      'direccion': direccion,
      'telefono': telefono,
      'creado_en': creadoEn,
      'foto_path': fotoPath,
    };
  }
}
