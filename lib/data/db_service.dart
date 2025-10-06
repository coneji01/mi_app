import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/cliente.dart'; // usa tu enum Sexo y SexoCodec

class DbService {
  // --------- Singleton ---------
  static final DbService _instance = DbService._();
  factory DbService() => _instance;
  DbService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'mi_app.db'),
      version: 1,
      onCreate: (db, v) async {
        // Esquema “completo” para instalaciones nuevas
        await _createClientes(db);
        await _createPrestamosPagos(db); // <-- NUEVO
      },
      onOpen: (db) async {
        // Asegura claves foráneas
        await db.execute('PRAGMA foreign_keys = ON;');

        // Migraciones y normalizaciones NO destructivas
        await _ensureClientes(db);
        await _ensurePrestamosPagos(db); // <-- NUEVO
      },
    );
    return _db!;
  }

  // =========================================================
  // ===============   CLIENTES: ESQUEMA BASE   ==============
  // =========================================================

  Future<void> _createClientes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre      TEXT NOT NULL,
        apellido    TEXT NOT NULL,
        cedula      TEXT,
        sexo        TEXT,
        direccion   TEXT NOT NULL,
        telefono    TEXT,
        creado_en   TEXT NOT NULL,
        foto_path   TEXT
      );
    ''');

    // Índice único parcial para cédula (ignora NULL y vacíos)
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_cedula
      ON clientes(cedula)
      WHERE cedula IS NOT NULL AND TRIM(cedula) <> '';
    ''');
  }

  // =========================================================
  // ========   PRÉSTAMOS / PAGOS: ESQUEMA BASE   ============
  // =========================================================

  Future<void> _createPrestamosPagos(Database db) async {
    // Tabla de préstamos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prestamos (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id        INTEGER NOT NULL,
        monto             REAL    NOT NULL,
        interes           REAL    NOT NULL,        -- % por período
        tipo_amortizacion TEXT    NOT NULL,        -- 'Interés Fijo', 'Francés', etc.
        modalidad         TEXT    NOT NULL,        -- 'Diario', 'Mensual', ...
        cuotas_totales    INTEGER NOT NULL,
        cuotas_pagadas    INTEGER NOT NULL DEFAULT 0,
        balance_pendiente REAL    NOT NULL,
        proximo_pago      TEXT,                    -- ISO
        anulado           INTEGER NOT NULL DEFAULT 0, -- 0/1
        creado_en         TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);');

    // Tabla de pagos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pagos (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamo_id  INTEGER NOT NULL,
        fecha        TEXT    NOT NULL,   -- ISO
        vence        TEXT,               -- ISO
        capital      REAL,               -- por cuota(s)
        interes      REAL,               -- por cuota(s)
        monto        REAL    NOT NULL,   -- total cobrado (capital+interés o pago libre)
        tipo         TEXT,               -- 'cuota', 'mora', 'ajuste', etc.
        nota         TEXT,
        creado_en    TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_prestamo ON pagos(prestamo_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha);');
  }

  // =========================================================
  // =========   CLIENTES: MIGRACIONES + NORMALIZAR   ========
  // =========================================================

  Future<bool> _tableHasColumn(Database db, String table, String column) async {
    final cols = await db.rawQuery("PRAGMA table_info('$table');");
    return cols.any((c) => (c['name'] as String).toLowerCase() == column.toLowerCase());
  }

  Future<void> _ensureColumn(Database db, String table, String column, String typeSql) async {
    if (!await _tableHasColumn(db, table, column)) {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $typeSql;");
    }
  }

  /// Asegura columnas requeridas por tu modelo y normaliza datos antiguos.
  Future<void> _ensureClientes(Database db) async {
    // Crea la tabla si no existiera (con un mínimo para que no falle)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre      TEXT NOT NULL,
        apellido    TEXT NOT NULL,
        cedula      TEXT,
        sexo        TEXT,
        direccion   TEXT,
        telefono    TEXT
      );
    ''');

    // Agrega columnas que falten en bases antiguas
    await _ensureColumn(db, 'clientes', 'direccion', 'TEXT');
    await _ensureColumn(db, 'clientes', 'creado_en', 'TEXT');
    await _ensureColumn(db, 'clientes', 'foto_path', 'TEXT');

    // Normalizaciones para cumplir Modelo (direccion/creado_en NO nulos)
    final nowIso = DateTime.now().toIso8601String();

    await db.execute("""
      UPDATE clientes SET direccion = '' WHERE direccion IS NULL;
    """);

    await db.rawUpdate(
      "UPDATE clientes SET creado_en = ? WHERE creado_en IS NULL OR TRIM(COALESCE(creado_en,'')) = ''",
      [nowIso],
    );

    // Normaliza sexo a M/F/O (tu SexoCodec lo usa así)
    await db.execute("""
      UPDATE clientes SET sexo = 'M' WHERE sexo IN ('Masculino','masculino','male');
    """);
    await db.execute("""
      UPDATE clientes SET sexo = 'F' WHERE sexo IN ('Femenino','femenino','female');
    """);
    await db.execute("""
      UPDATE clientes SET sexo = 'O' WHERE sexo IN ('Otro','otro','other');
    """);

    // Índice único parcial para cédula (ignora NULL y vacíos)
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_cedula
      ON clientes(cedula)
      WHERE cedula IS NOT NULL AND TRIM(cedula) <> '';
    ''');
  }

  // =========================================================
  // =======   PRÉSTAMOS/PAGOS: MIGRACIONES ENSURE   =========
  // =========================================================

  Future<void> _ensurePrestamosPagos(Database db) async {
    // Crea tablas si no existen (idempotente)
    await _createPrestamosPagos(db);

    // Asegura columnas faltantes de préstamos
    await _ensureColumn(db, 'prestamos', 'interes', 'REAL');
    await _ensureColumn(db, 'prestamos', 'tipo_amortizacion', 'TEXT');
    await _ensureColumn(db, 'prestamos', 'modalidad', 'TEXT');
    await _ensureColumn(db, 'prestamos', 'cuotas_totales', 'INTEGER');
    await _ensureColumn(db, 'prestamos', 'cuotas_pagadas', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'prestamos', 'balance_pendiente', 'REAL');
    await _ensureColumn(db, 'prestamos', 'proximo_pago', 'TEXT');
    await _ensureColumn(db, 'prestamos', 'anulado', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'prestamos', 'creado_en', "TEXT NOT NULL DEFAULT (datetime('now'))");

    // Defaults razonables si quedaron valores nulos
    await db.execute("""
      UPDATE prestamos
      SET cuotas_pagadas = COALESCE(cuotas_pagadas, 0)
    """);

    await db.execute("""
      UPDATE prestamos
      SET balance_pendiente = COALESCE(balance_pendiente, monto)
      WHERE balance_pendiente IS NULL AND monto IS NOT NULL;
    """);

    // Asegura columnas faltantes de pagos
    await _ensureColumn(db, 'pagos', 'vence', 'TEXT');
    await _ensureColumn(db, 'pagos', 'capital', 'REAL');
    await _ensureColumn(db, 'pagos', 'interes', 'REAL');
    await _ensureColumn(db, 'pagos', 'tipo', 'TEXT');
    await _ensureColumn(db, 'pagos', 'nota', 'TEXT');
    await _ensureColumn(db, 'pagos', 'creado_en', "TEXT NOT NULL DEFAULT (datetime('now'))");

    // Índices por si faltan
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_prestamo ON pagos(prestamo_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha);');
  }

  // =========================================================
  // =====================   UTILIDADES   ====================
  // =========================================================

  /// Normaliza la cédula: quita guiones, espacios y deja solo dígitos.
  static String? normalizeCedula(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  // =========================================================
  // ====================   CRUD CLIENTES   ==================
  // =========================================================

  Future<int> insertCliente(Cliente c) async {
    final db = await database;

    final cedulaNorm = normalizeCedula(c.cedula);

    final data = <String, Object?>{
      'nombre': c.nombre.trim(),
      'apellido': c.apellido.trim(),
      'cedula': cedulaNorm,
      'sexo': SexoCodec.toDb(c.sexo),   // guarda 'M'/'F'/'O'
      'direccion': c.direccion.trim(),  // requerido por tu modelo
      'telefono': c.telefono?.trim(),
      'creado_en': c.creadoEn,          // requerido por tu modelo
      'foto_path': c.fotoPath,
    };

    return db.insert('clientes', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> updateCliente(Cliente c) async {
    final db = await database;
    if (c.id == null) throw Exception('Cliente sin id');

    final cedulaNorm = normalizeCedula(c.cedula);

    final data = <String, Object?>{
      'nombre': c.nombre.trim(),
      'apellido': c.apellido.trim(),
      'cedula': cedulaNorm,
      'sexo': SexoCodec.toDb(c.sexo),
      'direccion': c.direccion.trim(),
      'telefono': c.telefono?.trim(),
      'creado_en': c.creadoEn,
      'foto_path': c.fotoPath,
    };

    return db.update('clientes', data, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteCliente(int id) async {
    final db = await database;
    return db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  Cliente _clienteFromMap(Map<String, dynamic> m) {
    // Con _ensureClientes ya garantizamos no-nulos para direccion/creado_en,
    // pero de todos modos ponemos fallback para máxima tolerancia.
    return Cliente(
      id: m['id'] as int?,
      nombre: (m['nombre'] as String?) ?? '',
      apellido: (m['apellido'] as String?) ?? '',
      cedula: m['cedula'] as String?,
      sexo: SexoCodec.fromDb(m['sexo'] as String?),
      direccion: (m['direccion'] as String?) ?? '',
      telefono: m['telefono'] as String?,
      creadoEn: (m['creado_en'] as String?) ?? '',
      fotoPath: m['foto_path'] as String?,
    );
  }

  /// Listado genérico (aliás de listarClientes)
  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final rows = await db.query('clientes', orderBy: 'creado_en DESC');
    return rows.map(_clienteFromMap).toList();
  }

  Future<List<Cliente>> listarClientes() async {
    final db = await database;
    final rows = await db.query('clientes', orderBy: 'id DESC');
    return rows.map(_clienteFromMap).toList();
  }

  Future<Cliente?> getClienteById(int id) async {
    final db = await database;
    final rows = await db.query('clientes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _clienteFromMap(rows.first);
  }

  // =========================================================
  // ====== El resto (préstamos/pagos) en db_service_ext.dart =
  // =========================================================
}
