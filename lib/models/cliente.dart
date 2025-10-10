// lib/models/cliente.dart

enum Sexo { masculino, femenino, otro }
enum EstadoCivil { soltero, casado, unionLibre, divorciado, viudo }

class SexoCodec {
  static String? encode(Sexo? s) {
    if (s == null) return null;
    switch (s) {
      case Sexo.masculino: return 'M';
      case Sexo.femenino:  return 'F';
      case Sexo.otro:      return 'O';
    }
  }

  static Sexo? decode(String? v) {
    switch (v) {
      case 'M': return Sexo.masculino;
      case 'F': return Sexo.femenino;
      case 'O': return Sexo.otro;
      default:  return null;
    }
  }

  // 👇 Para usar en UI: etiqueta humana
  static String legible(Sexo s) {
    switch (s) {
      case Sexo.masculino: return 'Masculino';
      case Sexo.femenino:  return 'Femenino';
      case Sexo.otro:      return 'Otro';
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
    return EstadoCivil.values.firstWhere(
      (e) => e.toString().split('.').last == v,
      orElse: () => EstadoCivil.soltero,
    );
  }

  // 👇 Para usar en UI
  static String legible(EstadoCivil e) {
    switch (e) {
      case EstadoCivil.soltero:     return 'Soltero';
      case EstadoCivil.casado:      return 'Casado';
      case EstadoCivil.unionLibre:  return 'Unión libre';
      case EstadoCivil.divorciado:  return 'Divorciado';
      case EstadoCivil.viudo:       return 'Viudo';
    }
  }
}

class Cliente {
  int? id;

  // Personales (todas opcionales)
  String? nombre;
  String? apellido;
  String? telefono;
  String? direccion;
  String? cedula;
  Sexo? sexo;
  String? creadoEn;
  String? fotoPath;

  // Laborales (opcionales)
  String? empresa;
  double? ingresos;
  EstadoCivil? estadoCivil;
  int? dependientes;
  String? direccionTrabajo;
  String? puestoTrabajo;
  int? mesesTrabajando;

  Cliente({
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
    ingresos: (m['ingresos'] as num?)?.toDouble(),
    estadoCivil: EstadoCivilCodec.decode(m['estado_civil'] as String?),
    dependientes: (m['dependientes'] as num?)?.toInt(),
    direccionTrabajo: m['direccion_trabajo'] as String?,
    puestoTrabajo: m['puesto_trabajo'] as String?,
    mesesTrabajando: (m['meses_trabajando'] as num?)?.toInt(),
  );

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
}
