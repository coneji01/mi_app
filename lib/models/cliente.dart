// lib/models/cliente.dart

enum Sexo { masculino, femenino, otro }
enum EstadoCivil { soltero, casado, unionLibre, divorciado, viudo }

class SexoCodec {
  static String? encode(Sexo? s) {
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

  static Sexo? decode(String? v) {
    switch (v) {
      case 'M':
        return Sexo.masculino;
      case 'F':
        return Sexo.femenino;
      case 'O':
        return Sexo.otro;
      default:
        return null;
    }
  }

  static String legible(Sexo s) {
    switch (s) {
      case Sexo.masculino:
        return 'Masculino';
      case Sexo.femenino:
        return 'Femenino';
      case Sexo.otro:
        return 'Otro';
    }
  }
}

class EstadoCivilCodec {
  static String? encode(EstadoCivil? e) {
    if (e == null) return null;
    return e.toString().split('.').last; // soltero, casado, ...
  }

  static EstadoCivil? decode(String? v) {
    if (v == null) return null;
    final val = v.trim();
    // admitir variantes comunes
    switch (val) {
      case 'soltero':
        return EstadoCivil.soltero;
      case 'casado':
        return EstadoCivil.casado;
      case 'unionLibre':
      case 'union_libre':
      case 'unionlibre':
        return EstadoCivil.unionLibre;
      case 'divorciado':
        return EstadoCivil.divorciado;
      case 'viudo':
        return EstadoCivil.viudo;
      default:
        return EstadoCivil.soltero;
    }
  }

  static String legible(EstadoCivil e) {
    switch (e) {
      case EstadoCivil.soltero:
        return 'Soltero';
      case EstadoCivil.casado:
        return 'Casado';
      case EstadoCivil.unionLibre:
        return 'Unión libre';
      case EstadoCivil.divorciado:
        return 'Divorciado';
      case EstadoCivil.viudo:
        return 'Viudo';
    }
  }
}

class Cliente {
  final int? id;

  // Personales (opcionales)
  final String? nombre;
  final String? apellido;
  final String? telefono;
  final String? direccion;
  final String? cedula;
  final Sexo? sexo;
  final String? creadoEn; // ISO8601 del backend
  final String? fotoPath;

  // Laborales (opcionales)
  final String? empresa;
  final double? ingresos;
  final EstadoCivil? estadoCivil;
  final int? dependientes;
  final String? direccionTrabajo;
  final String? puestoTrabajo;
  final int? mesesTrabajando;

  const Cliente({
    this.id,
    this.nombre,
    this.apellido,
    this.telefono,
    this.direccion,
    this.cedula,
    this.sexo,
    this.creadoEn,
    this.fotoPath,
    this.empresa,
    this.ingresos,
    this.estadoCivil,
    this.dependientes,
    this.direccionTrabajo,
    this.puestoTrabajo,
    this.mesesTrabajando,
  });

  // --------- Decoders ----------
  factory Cliente.fromMap(Map<String, dynamic> m) => Cliente(
        id: m['id'] as int?,
        nombre: m['nombre'] as String?,
        apellido: m['apellido'] as String?,
        telefono: m['telefono'] as String?,
        direccion: m['direccion'] as String?,
        cedula: m['cedula'] as String?,
        sexo: SexoCodec.decode(m['sexo'] as String?),
        creadoEn: m['creado_en'] as String?,
        fotoPath: m['foto_path'] as String?,
        empresa: m['empresa'] as String?,
        ingresos: _toDouble(m['ingresos']),
        estadoCivil: EstadoCivilCodec.decode(m['estado_civil'] as String?),
        dependientes: _toInt(m['dependientes']),
        direccionTrabajo: m['direccion_trabajo'] as String?,
        puestoTrabajo: m['puesto_trabajo'] as String?,
        mesesTrabajando: _toInt(m['meses_trabajando']),
      );

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente.fromMap(json);

  // --------- Encoders ----------
  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'direccion': direccion,
        'cedula': cedula,
        'sexo': SexoCodec.encode(sexo),
        'creado_en': creadoEn,
        'foto_path': fotoPath,
        'empresa': empresa,
        'ingresos': ingresos,
        'estado_civil': EstadoCivilCodec.encode(estadoCivil),
        'dependientes': dependientes,
        'direccion_trabajo': direccionTrabajo,
        'puesto_trabajo': puestoTrabajo,
        'meses_trabajando': mesesTrabajando,
      };

  Map<String, dynamic> toJson() => toMap();

  /// Payload para **crear** en API (no manda campos de solo lectura ni `id`)
  Map<String, dynamic> toCreatePayload() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'direccion': direccion,
        'cedula': cedula,
        'sexo': SexoCodec.encode(sexo),
        'foto_path': fotoPath,
        'empresa': empresa,
        'ingresos': ingresos,
        'estado_civil': EstadoCivilCodec.encode(estadoCivil),
        'dependientes': dependientes,
        'direccion_trabajo': direccionTrabajo,
        'puesto_trabajo': puestoTrabajo,
        'meses_trabajando': mesesTrabajando,
      }..removeWhere((k, v) => v == null);

  /// Payload para **actualizar** en API (no manda `id` ni `creado_en`)
  Map<String, dynamic> toUpdatePayload() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'direccion': direccion,
        'cedula': cedula,
        'sexo': SexoCodec.encode(sexo),
        'foto_path': fotoPath,
        'empresa': empresa,
        'ingresos': ingresos,
        'estado_civil': EstadoCivilCodec.encode(estadoCivil),
        'dependientes': dependientes,
        'direccion_trabajo': direccionTrabajo,
        'puesto_trabajo': puestoTrabajo,
        'meses_trabajando': mesesTrabajando,
      }..removeWhere((k, v) => v == null);

  // --------- Utils ----------
  Cliente copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? telefono,
    String? direccion,
    String? cedula,
    Sexo? sexo,
    String? creadoEn,
    String? fotoPath,
    String? empresa,
    double? ingresos,
    EstadoCivil? estadoCivil,
    int? dependientes,
    String? direccionTrabajo,
    String? puestoTrabajo,
    int? mesesTrabajando,
  }) =>
      Cliente(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        apellido: apellido ?? this.apellido,
        telefono: telefono ?? this.telefono,
        direccion: direccion ?? this.direccion,
        cedula: cedula ?? this.cedula,
        sexo: sexo ?? this.sexo,
        creadoEn: creadoEn ?? this.creadoEn,
        fotoPath: fotoPath ?? this.fotoPath,
        empresa: empresa ?? this.empresa,
        ingresos: ingresos ?? this.ingresos,
        estadoCivil: estadoCivil ?? this.estadoCivil,
        dependientes: dependientes ?? this.dependientes,
        direccionTrabajo: direccionTrabajo ?? this.direccionTrabajo,
        puestoTrabajo: puestoTrabajo ?? this.puestoTrabajo,
        mesesTrabajando: mesesTrabajando ?? this.mesesTrabajando,
      );

  @override
  String toString() => 'Cliente(id:$id, nombre:$nombre $apellido, ced:$cedula)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cliente &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          apellido == other.apellido &&
          telefono == other.telefono &&
          direccion == other.direccion &&
          cedula == other.cedula &&
          sexo == other.sexo &&
          empresa == other.empresa &&
          ingresos == other.ingresos &&
          estadoCivil == other.estadoCivil &&
          dependientes == other.dependientes &&
          direccionTrabajo == other.direccionTrabajo &&
          puestoTrabajo == other.puestoTrabajo &&
          mesesTrabajando == other.mesesTrabajando &&
          creadoEn == other.creadoEn &&
          fotoPath == other.fotoPath;

  @override
  int get hashCode =>
      id.hashCode ^
      (nombre ?? '').hashCode ^
      (apellido ?? '').hashCode ^
      (telefono ?? '').hashCode ^
      (direccion ?? '').hashCode ^
      (cedula ?? '').hashCode ^
      (sexo?.index ?? -1) ^
      (empresa ?? '').hashCode ^
      (ingresos ?? 0.0).hashCode ^
      (estadoCivil?.index ?? -1) ^
      (dependientes ?? -1).hashCode ^
      (direccionTrabajo ?? '').hashCode ^
      (puestoTrabajo ?? '').hashCode ^
      (mesesTrabajando ?? -1).hashCode ^
      (creadoEn ?? '').hashCode ^
      (fotoPath ?? '').hashCode;
}

// --------- helpers de casteo seguros ---------
double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}
