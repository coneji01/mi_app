// lib/data/db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/cliente.dart';
import '../models/prestamo.dart';

class DbService {
  // ────────────────── Singleton ──────────────────
  DbService._();
  static final DbService instance = DbService._();

  static Database? _database;

  /// Getter interno usado por los métodos del servicio.
  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  /// Getter público para otros servicios (p.ej. PagosService)
  Future<Database> get database async => await _db;

  // ────────────────── Inicialización ──────────────────
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'mi_app.db');
    return openDatabase(
      path,
      version: 3, // ⬅️ subimos versión para aplicar migración
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        // Esquema laxo (permite NULL) en clientes (snake_case)
        await db.execute('''
          CREATE TABLE clientes (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre     TEXT,
            apellido   TEXT,
            telefono   TEXT,
            direccion  TEXT,
            cedula     TEXT,
            sexo       TEXT,   -- 'M' | 'F' | 'O'
            creado_en  TEXT,   -- ISO-8601
            foto_path  TEXT
          );
        ''');

        // prestamos/pagos en camelCase, como usa tu código
        await db.execute('''
          CREATE TABLE prestamos (
            id                INTEGER PRIMARY KEY AUTOINCREMENT,
            clienteId         INTEGER NOT NULL,
            monto             REAL    NOT NULL,
            balancePendiente  REAL    NOT NULL,
            totalAPagar       REAL    NOT NULL,
            cuotasTotales     INTEGER NOT NULL,
            cuotasPagadas     INTEGER NOT NULL,
            interes           REAL    NOT NULL,  -- 0..1 por periodo
            modalidad         TEXT    NOT NULL,
            tipoAmortizacion  TEXT    NOT NULL,
            fechaInicio       TEXT    NOT NULL,  -- ISO-8601
            proximoPago       TEXT,              -- ISO-8601
            FOREIGN KEY (clienteId) REFERENCES clientes(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('''
          CREATE TABLE pagos (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            prestamoId INTEGER NOT NULL,
            monto      REAL    NOT NULL,
            fecha      TEXT    NOT NULL,   -- ISO-8601
            nota       TEXT,
            FOREIGN KEY (prestamoId) REFERENCES prestamos(id) ON DELETE CASCADE
          );
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // v2 ya recreaba "clientes" a snake_case
        if (oldV < 2) {
          await db.execute('DROP TABLE IF EXISTS clientes;');
          await db.execute('''
            CREATE TABLE clientes (
              id         INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre     TEXT,
              apellido   TEXT,
              telefono   TEXT,
              direccion  TEXT,
              cedula     TEXT,
              sexo       TEXT,
              creado_en  TEXT,
              foto_path  TEXT
            );
          ''');
        }

        // v3: asegurar columnas camelCase en prestamos/pagos (clienteId, prestamoId)
        if (oldV < 3) {
          await db.execute('DROP TABLE IF EXISTS pagos;');
          await db.execute('DROP TABLE IF EXISTS prestamos;');

          await db.execute('''
            CREATE TABLE prestamos (
              id                INTEGER PRIMARY KEY AUTOINCREMENT,
              clienteId         INTEGER NOT NULL,
              monto             REAL    NOT NULL,
              balancePendiente  REAL    NOT NULL,
              totalAPagar       REAL    NOT NULL,
              cuotasTotales     INTEGER NOT NULL,
              cuotasPagadas     INTEGER NOT NULL,
              interes           REAL    NOT NULL,
              modalidad         TEXT    NOT NULL,
              tipoAmortizacion  TEXT    NOT NULL,
              fechaInicio       TEXT    NOT NULL,
              proximoPago       TEXT,
              FOREIGN KEY (clienteId) REFERENCES clientes(id) ON DELETE CASCADE
            );
          ''');

          await db.execute('''
            CREATE TABLE pagos (
              id         INTEGER PRIMARY KEY AUTOINCREMENT,
              prestamoId INTEGER NOT NULL,
              monto      REAL    NOT NULL,
              fecha      TEXT    NOT NULL,
              nota       TEXT,
              FOREIGN KEY (prestamoId) REFERENCES prestamos(id) ON DELETE CASCADE
            );
          ''');
        }
      },
    );
  }

  // ────────────────── Utilidades ──────────────────

  /// Normaliza cédula: deja solo dígitos; null si queda vacía.
  static String? normalizeCedula(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }

  /// Borra contenido de las tablas (útil en pruebas).
  Future<void> nuke() async {
    final db = await _db;
    await db.delete('pagos');
    await db.delete('prestamos');
    await db.delete('clientes');
  }

  // ────────────────── CLIENTES ──────────────────

  /// Convierte '' -> null para guardar "vacío" como NULL
  String? _n(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<int> insertCliente(Cliente c) async {
    final db = await _db;

    final data = <String, Object?>{
      'nombre'    : _n(c.nombre),
      'apellido'  : _n(c.apellido),
      'telefono'  : _n(c.telefono),
      'direccion' : _n(c.direccion),
      'cedula'    : _n(c.cedula),
      'sexo'      : SexoCodec.toDb(c.sexo), // 'M','F','O' o null
      'creado_en' : _n(c.creadoEn),         // snake_case
      'foto_path' : _n(c.fotoPath),         // snake_case
    };

    return db.insert('clientes', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> updateCliente(Cliente c) async {
    final db = await _db;
    if (c.id == null) {
      throw ArgumentError('Cliente.id es requerido para actualizar');
    }

    final data = <String, Object?>{
      'nombre'    : _n(c.nombre),
      'apellido'  : _n(c.apellido),
      'telefono'  : _n(c.telefono),
      'direccion' : _n(c.direccion),
      'cedula'    : _n(c.cedula),
      'sexo'      : SexoCodec.toDb(c.sexo),
      'creado_en' : _n(c.creadoEn),
      'foto_path' : _n(c.fotoPath),
    };

    return db.update(
      'clientes',
      data,
      where: 'id = ?',
      whereArgs: [c.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Lista clientes (con filtro opcional por nombre/apellido/teléfono).
  Future<List<Cliente>> getClientes({
    String? filtro,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    String where = '';
    List<Object?> args = [];

    if (filtro != null && filtro.trim().isNotEmpty) {
      final q = '%${filtro.trim()}%';
      where = 'WHERE nombre LIKE ? OR apellido LIKE ? OR telefono LIKE ?';
      args = [q, q, q];
    }

    final lim = (limit != null) ? ' LIMIT $limit' : '';
    final off = (offset != null && offset > 0) ? ' OFFSET $offset' : '';

    final rows = await db.rawQuery('''
      SELECT
        id, nombre, apellido, telefono, direccion, cedula, sexo, creado_en, foto_path
      FROM clientes
      $where
      ORDER BY nombre COLLATE NOCASE ASC, apellido COLLATE NOCASE ASC
      $lim$off
    ''', args);

    return rows.map((m) => Cliente.fromMap(m)).toList();
  }

  /// Obtiene un cliente por ID.
  Future<Cliente?> getClienteById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Cliente.fromMap(rows.first);
  }

  // ────────────────── PRÉSTAMOS ──────────────────

  /// Inserta un préstamo y devuelve el id.
  Future<int> crearPrestamo(Prestamo p) async {
    final db = await _db;
    final data = <String, Object?>{
      'clienteId'       : p.clienteId,
      'monto'           : p.monto,
      'balancePendiente': p.balancePendiente,
      'totalAPagar'     : p.totalAPagar,
      'cuotasTotales'   : p.cuotasTotales,
      'cuotasPagadas'   : p.cuotasPagadas,
      'interes'         : p.interes,
      'modalidad'       : p.modalidad,
      'tipoAmortizacion': p.tipoAmortizacion,
      'fechaInicio'     : p.fechaInicio,
      'proximoPago'     : p.proximoPago,
    };
    return db.insert('prestamos', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<Prestamo?> getPrestamoById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'prestamos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Prestamo.fromMap(rows.first);
  }

  /// Préstamos + datos del cliente (para listados).
  Future<List<Map<String, dynamic>>> listarPrestamosConCliente() async {
    final db = await _db;
    const sql = '''
      SELECT
        p.id                            AS prestamoId,
        p.clienteId                     AS clienteId,
        c.nombre                        AS clienteNombre,
        c.apellido                      AS clienteApellido,
        (c.nombre || ' ' || c.apellido) AS clienteNombreCompleto,
        p.monto,
        p.balancePendiente,
        p.totalAPagar,
        p.cuotasTotales,
        p.cuotasPagadas,
        p.interes,
        p.modalidad,
        p.tipoAmortizacion,
        p.fechaInicio,
        p.proximoPago
      FROM prestamos p
      LEFT JOIN clientes c ON c.id = p.clienteId
      ORDER BY p.id DESC
    ''';
    return db.rawQuery(sql);
  }

  // ────────────────── PAGOS ──────────────────

  /// Inserta un pago y, si `tipo == 'capital'`, reduce el balancePendiente.
  /// NOTA: `tipo` se guarda como etiqueta dentro de `nota` -> "[tipo] ...".
  Future<void> agregarPagoRapido({
    required int prestamoId,
    required double monto,
    String? nota,
    String? tipo, // 'capital','interes','mora','seguro','gastos','otros'
  }) async {
    final db = await _db;
    final ahoraIso = DateTime.now().toIso8601String();

    final notaFinal = (tipo == null || tipo.isEmpty)
        ? nota
        : (nota == null || nota.isEmpty ? '[$tipo]' : '[$tipo] $nota');

    await db.transaction((txn) async {
      // 1) Insertar pago
      await txn.insert('pagos', {
        'prestamoId': prestamoId,
        'monto': monto,
        'fecha': ahoraIso,
        'nota': notaFinal,
      });

      // 2) Si es capital, actualizar balance del préstamo
      if ((tipo ?? '').toLowerCase() == 'capital') {
        final rows = await txn.query(
          'prestamos',
          columns: ['balancePendiente'],
          where: 'id = ?',
          whereArgs: [prestamoId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final bal = (rows.first['balancePendiente'] as num?)?.toDouble() ?? 0.0;
          final nuevo = bal - monto;
          await txn.update(
            'prestamos',
            {'balancePendiente': (nuevo < 0 ? 0.0 : nuevo)},
            where: 'id = ?',
            whereArgs: [prestamoId],
          );
        }
      }
    });
  }

  /// Lista pagos de un préstamo (más recientes primero).
  Future<List<Map<String, dynamic>>> listarPagosDePrestamo(int prestamoId) async {
    final db = await _db;
    return db.query(
      'pagos',
      where: 'prestamoId = ?',
      whereArgs: [prestamoId],
      orderBy: 'fecha DESC, id DESC',
    );
  }
}
