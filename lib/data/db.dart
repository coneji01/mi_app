// lib/data/db.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Desktop (Windows/macOS/Linux)
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

// Web (IndexedDB)
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'mi_app.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<void> ensureInitialized() async {
    await database;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;

    // Selección del factory por plataforma
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;            // ✅ Web
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;           // ✅ Desktop
    } else {
      // Android/iOS: usa el factory por defecto de sqflite (no hacer nada)
    }

    final basePath = await databaseFactory.getDatabasesPath();
    final fullPath = kIsWeb ? _dbName : p.join(basePath, _dbName);

    _db = await databaseFactory.openDatabase(
      fullPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON;'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    return _db!;
  }

  // ================= Esquema v1 =================
  Future<void> _onCreate(Database db, int version) async {
    // CLIENTES
    await db.execute('''
      CREATE TABLE clientes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre    TEXT NOT NULL,
        apellido  TEXT,
        telefono  TEXT,
        direccion TEXT
      );
    ''');

    // PRESTAMOS (incluye campos usados por tus pantallas)
    await db.execute('''
      CREATE TABLE prestamos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        monto      REAL    NOT NULL,
        interes    REAL    NOT NULL,
        cuotas     INTEGER NOT NULL,
        saldo      REAL    NOT NULL,
        estado     TEXT    NOT NULL DEFAULT 'activo',
        creado_en  TEXT,
        balance_pendiente REAL,
        total_a_pagar     REAL,
        cuotas_totales    INTEGER,
        cuotas_pagadas    INTEGER,
        tipo_amortizacion TEXT,
        fecha_inicio      TEXT,
        proximo_pago      TEXT,
        tags              TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
      );
    ''');

    // PAGOS
    await db.execute('''
      CREATE TABLE pagos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prestamo_id    INTEGER NOT NULL,
        monto_capital  REAL    NOT NULL,
        monto_interes  REAL    NOT NULL,
        fecha          TEXT    NOT NULL,
        nota           TEXT,
        FOREIGN KEY (prestamo_id) REFERENCES prestamos(id) ON DELETE CASCADE
      );
    ''');

    // Índices útiles
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prestamos_cliente ON prestamos(cliente_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pagos_prestamo   ON pagos(prestamo_id);');
  }

  // ================= Migraciones futuras =================
  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // if (oldV < 2) { ... }
  }
}
