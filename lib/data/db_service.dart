// lib/data/db_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/cliente.dart';
import '../models/prestamo.dart';
import '../models/pago_vista.dart'; // DTO para la pantalla de Pagos

class DbService {
  // ────────────────── Singleton ──────────────────
  DbService._();
  static final DbService instance = DbService._();

  static Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> get database async => await _db;

  // ────────────────── Inicialización ──────────────────
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'mi_app.db');
    return openDatabase(
      path,
      version: 4, // ⬅️ subimos a v4 para asegurar el índice UNIQUE de cédula
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
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

        // Índice único por cédula (permite múltiples NULL)
        await _ensureCedulaUniqueIndex(db);

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
      },
      onUpgrade: (db, oldV, newV) async {
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

        // v4: asegurar índice UNIQUE de cédula
        if (oldV < 4) {
          await _ensureCedulaUniqueIndex(db);
        }
      },
    );
  }

  /// Crea el índice único en cédula (solo impone unicidad cuando no es NULL).
  Future<void> _ensureCedulaUniqueIndex(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_clientes_cedula '
      'ON clientes(cedula) WHERE cedula IS NOT NULL;',
    );
  }

  // ────────────────── Utilidades ──────────────────

  /// Normaliza cédula: solo dígitos; si queda vacía -> null.
  static String? normalizeCedula(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }

  Future<bool> _cedulaExiste(String cedula, {int? excludeId}) async {
    final db = await _db;
    final rows = await db.query(
      'clientes',
      columns: const ['id'],
      where: excludeId == null
          ? 'cedula = ?'
          : 'cedula = ? AND id <> ?',
      whereArgs: excludeId == null ? [cedula] : [cedula, excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> nuke() async {
    final db = await _db;
    await db.delete('pagos');
    await db.delete('prestamos');
    await db.delete('clientes');
  }

  String? _n(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  // ────────────────── CLIENTES ──────────────────

  Future<int> insertCliente(Cliente c) async {
    final db = await _db;

    final ced = normalizeCedula(c.cedula); // ⬅️ normalizamos
    if (ced != null && await _cedulaExiste(ced)) {
      // Mensaje claro para la UI
      throw Exception('La cédula $ced ya está registrada en otro cliente.');
    }

    final data = <String, Object?>{
      'nombre'    : _n(c.nombre),
      'apellido'  : _n(c.apellido),
      'telefono'  : _n(c.telefono),
      'direccion' : _n(c.direccion),
      'cedula'    : ced,                  // ⬅️ guardamos normalizada o NULL
      'sexo'      : SexoCodec.toDb(c.sexo),
      'creado_en' : _n(c.creadoEn),
      'foto_path' : _n(c.fotoPath),
    };

    return db.insert('clientes', data, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> updateCliente(Cliente c) async {
    final db = await _db;
    if (c.id == null) {
      throw ArgumentError('Cliente.id es requerido para actualizar');
    }

    final ced = normalizeCedula(c.cedula);
    if (ced != null && await _cedulaExiste(ced, excludeId: c.id)) {
      throw Exception('La cédula $ced ya está registrada en otro cliente.');
    }

    final data = <String, Object?>{
      'nombre'    : _n(c.nombre),
      'apellido'  : _n(c.apellido),
      'telefono'  : _n(c.telefono),
      'direccion' : _n(c.direccion),
      'cedula'    : ced,
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
        p.proximoPago,

        max(0, p.monto - ifnull((
          SELECT SUM(pg.monto)
            FROM pagos pg
           WHERE pg.prestamoId = p.id
             AND (pg.nota LIKE '[capital]%' OR pg.nota LIKE '[CAPITAL]%')
        ), 0)) AS balanceCalculado

      FROM prestamos p
      LEFT JOIN clientes c ON c.id = p.clienteId
      ORDER BY p.id DESC
    ''';
    return db.rawQuery(sql);
  }

  // ────────────────── PAGOS ──────────────────

  Future<void> agregarPagoRapido({
    required int prestamoId,
    required double monto,
    String? nota,
    String? tipo, // 'capital','interes','mora','seguro','gastos','otros'
  }) async {
    final db = await _db;
    final ahoraIso = DateTime.now().toIso8601String();

    final tag = (tipo ?? '').trim().toLowerCase();
    final notaFinal =
        tag.isEmpty ? nota : (nota == null || nota.isEmpty ? '[$tag]' : '[$tag] $nota');

    await db.transaction((txn) async {
      await txn.insert('pagos', {
        'prestamoId': prestamoId,
        'monto': monto,
        'fecha': ahoraIso,
        'nota': notaFinal,
      });

      if (tag == 'capital') {
        final pr = await txn.query(
          'prestamos',
          columns: ['balancePendiente', 'cuotasTotales', 'cuotasPagadas'],
          where: 'id = ?',
          whereArgs: [prestamoId],
          limit: 1,
        );
        if (pr.isNotEmpty) {
          final oldBal = (pr.first['balancePendiente'] as num?)?.toDouble() ?? 0.0;
          final cuotasTot = (pr.first['cuotasTotales'] as num).toInt();
          final newBal = (oldBal - monto) <= 0 ? 0.0 : (oldBal - monto);

          if (newBal == 0.0) {
            await txn.update(
              'prestamos',
              {
                'balancePendiente': 0.0,
                'cuotasPagadas': cuotasTot,
                'proximoPago': null,
              },
              where: 'id = ?',
              whereArgs: [prestamoId],
            );
          } else {
            await txn.update(
              'prestamos',
              {'balancePendiente': newBal},
              where: 'id = ?',
              whereArgs: [prestamoId],
            );
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> listarPagosDePrestamo(int prestamoId) async {
    final db = await _db;
    return db.query(
      'pagos',
      where: 'prestamoId = ?',
      whereArgs: [prestamoId],
      orderBy: 'fecha DESC, id DESC',
    );
  }

  Future<void> registrarPagoCuota({
    required int prestamoId,
    required int numeroCuota,
    double capital = 0,
    double interes = 0,
    double mora = 0,
    double otros = 0,
    String? nota,
  }) async {
    final db = await _db;
    final ahoraIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final prRows = await txn.query(
        'prestamos',
        where: 'id = ?',
        whereArgs: [prestamoId],
        limit: 1,
      );
      if (prRows.isEmpty) {
        throw StateError('Préstamo $prestamoId no existe');
      }
      final pr = prRows.first;
      final double balance = (pr['balancePendiente'] as num?)?.toDouble() ?? 0.0;
      final int cuotasTotales = (pr['cuotasTotales'] as num).toInt();
      final int cuotasPagadas = (pr['cuotasPagadas'] as num?)?.toInt() ?? 0;
      final String modalidad = (pr['modalidad'] as String?) ?? 'Quincenal';
      final String? fechaInicioIso = pr['fechaInicio'] as String?;
      final String? proximoPagoIso = pr['proximoPago'] as String?;

      Future<void> _ins(double monto, String tag) async {
        if (monto <= 0) return;
        await txn.insert('pagos', {
          'prestamoId': prestamoId,
          'monto': monto,
          'fecha': ahoraIso,
          'nota': '[$tag] ${nota ?? ''}'.trim(),
        });
      }

      await _ins(capital, 'capital');
      await _ins(interes, 'interes');
      await _ins(mora, 'mora');
      await _ins(otros, 'otros');

      final nuevoBalance = balance - capital;
      final balanceFinal = nuevoBalance < 0 ? 0.0 : nuevoBalance;

      int nuevasCuotasPagadas;
      String? nuevoProximoPago;
      if (balanceFinal == 0.0) {
        nuevasCuotasPagadas = cuotasTotales;
        nuevoProximoPago = null;
      } else {
        nuevasCuotasPagadas =
            (cuotasPagadas + 1) > cuotasTotales ? cuotasTotales : (cuotasPagadas + 1);

        DateTime base;
        if (proximoPagoIso != null) {
          base = DateTime.tryParse(proximoPagoIso) ?? DateTime.now();
        } else if (fechaInicioIso != null) {
          base = DateTime.tryParse(fechaInicioIso) ?? DateTime.now();
        } else {
          base = DateTime.now();
        }
        Duration paso;
        final low = modalidad.toLowerCase();
        if (low.contains('seman')) {
          paso = const Duration(days: 7);
        } else if (low.contains('mens')) {
          paso = const Duration(days: 30);
        } else {
          paso = const Duration(days: 14);
        }
        nuevoProximoPago = base.add(paso).toIso8601String();
      }

      await txn.update(
        'prestamos',
        {
          'balancePendiente': balanceFinal,
          'cuotasPagadas': nuevasCuotasPagadas,
          'proximoPago': nuevoProximoPago,
        },
        where: 'id = ?',
        whereArgs: [prestamoId],
      );
    });
  }

  // ============ Pagos con nombre de cliente ============
  Future<List<PagoVista>> listarPagosConCliente({int? limit}) async {
    final db = await _db;
    final lim = (limit != null && limit > 0) ? ' LIMIT $limit' : '';

    final rows = await db.rawQuery('''
      SELECT
        pg.id                AS pagoId,
        pg.prestamoId        AS prestamoId,
        pr.clienteId         AS clienteId,
        TRIM(COALESCE(c.nombre, '') || ' ' || COALESCE(c.apellido, '')) AS clienteNombre,
        pg.monto             AS monto,
        pg.fecha             AS fecha,
        pg.nota              AS nota
      FROM pagos pg
      INNER JOIN prestamos pr ON pr.id = pg.prestamoId
      LEFT JOIN clientes  c   ON c.id = pr.clienteId
      ORDER BY pg.fecha DESC, pg.id DESC
      $lim
    ''');

    return rows.map((m) => PagoVista.fromMap(m)).toList();
  }

  // ────────────────── Estadísticas para INICIO ──────────────────

  Duration _pasoPorModalidad(String modalidad) {
    final low = modalidad.toLowerCase();
    if (low.contains('seman')) return const Duration(days: 7);
    if (low.contains('mens')) return const Duration(days: 30);
    return const Duration(days: 14);
  }

  String _notaTag(String? nota) {
    if (nota == null) return 'otros';
    final m = RegExp(r'^\s*\[([^\]]+)\]').firstMatch(nota);
    return (m?.group(1) ?? 'otros').toLowerCase();
  }

  Future<({int activos, int total})> conteoClientesActivosYTotal() async {
    final db = await _db;
    final total = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM clientes'),
        ) ?? 0;

    final activos = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(DISTINCT clienteId)
      FROM prestamos
      WHERE balancePendiente > 0
    ''')) ?? 0;

    return (activos: activos, total: total);
  }

  Future<({int activos, int totalPrestamo, int totalClientes})>
      conteoClientesActivosDetalle() async {
    final db = await _db;

    final totalClientes = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM clientes'),
        ) ?? 0;

    final totalPrestamo = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(DISTINCT clienteId) FROM prestamos
    ''')) ?? 0;

    final activos = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(DISTINCT clienteId)
      FROM prestamos
      WHERE balancePendiente > 0
    ''')) ?? 0;

    return (activos: activos, totalPrestamo: totalPrestamo, totalClientes: totalClientes);
  }

  Future<({int activos, int total})> conteoPrestamosActivosYTotal() async {
    final db = await _db;
    final total = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM prestamos'),
        ) ?? 0;
    final activos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM prestamos WHERE balancePendiente > 0'),
        ) ?? 0;
    return (activos: activos, total: total);
  }

  Future<double> totalPrestado() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT IFNULL(SUM(monto),0) AS s FROM prestamos');
    return (rows.first['s'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> proyeccionInteresMes(int year, int month) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT id, monto, interes, modalidad, fechaInicio, cuotasTotales
      FROM prestamos
    ''');

    double total = 0.0;
    for (final r in rows) {
      final double monto = (r['monto'] as num).toDouble();
      final double interes = (r['interes'] as num).toDouble();
      final String modalidad = (r['modalidad'] as String?) ?? 'Quincenal';
      final int cuotasTotales = (r['cuotasTotales'] as num).toInt();
      final DateTime? inicio = DateTime.tryParse((r['fechaInicio'] as String?) ?? '');
      if (inicio == null || cuotasTotales <= 0) continue;

      final paso = _pasoPorModalidad(modalidad);
      final interesPorCuota = monto * (interes / 100.0);

      for (int k = 1; k <= cuotasTotales; k++) {
        final due = inicio.add(Duration(days: paso.inDays * k));
        if (due.year == year && due.month == month) {
          total += interesPorCuota;
        }
      }
    }
    return total;
  }

  Future<Map<int, Map<String, double>>> resumenPagosPorMesDelAnio(int year) async {
    final db = await _db;
    final desde = DateTime(year, 1, 1).toIso8601String();
    final hasta = DateTime(year + 1, 1, 1).toIso8601String();

    final rows = await db.query(
      'pagos',
      columns: ['fecha', 'monto', 'nota'],
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [desde, hasta],
      orderBy: 'fecha ASC',
    );

    final Map<int, Map<String, double>> out = {
      for (var m = 1; m <= 12; m++)
        m: {
          'capital': 0,
          'interes': 0,
          'mora': 0,
          'seguro': 0,
          'otros': 0,
          'gastos': 0,
        }
    };

    for (final r in rows) {
      final d = DateTime.tryParse((r['fecha'] as String?) ?? '');
      if (d == null) continue;
      final m = d.month;
      final monto = (r['monto'] as num?)?.toDouble() ?? 0.0;
      final tag = _notaTag(r['nota'] as String?);

      if (out[m]!.containsKey(tag)) {
        out[m]![tag] = (out[m]![tag] ?? 0) + monto;
      } else {
        out[m]!['otros'] = (out[m]!['otros'] ?? 0) + monto;
      }
    }
    return out;
  }

  Future<({double ingreso, double egreso})> ingresoEgresoMes(int year, int month) async {
    final db = await _db;
    final desde = DateTime(year, month, 1);
    final hasta = DateTime(year, month + 1, 1);
    final rows = await db.query(
      'pagos',
      columns: ['fecha', 'monto', 'nota'],
      where: 'fecha >= ? AND fecha < ?',
      whereArgs: [desde.toIso8601String(), hasta.toIso8601String()],
    );

    double ingreso = 0, egreso = 0;
    for (final r in rows) {
      final monto = (r['monto'] as num?)?.toDouble() ?? 0.0;
      final tag = _notaTag(r['nota'] as String?);
      switch (tag) {
        case 'capital':
        case 'interes':
        case 'mora':
        case 'otros':
          ingreso += monto;
          break;
        case 'seguro':
        case 'gastos':
          egreso += monto;
          break;
        default:
          ingreso += monto;
      }
    }
    return (ingreso: ingreso, egreso: egreso);
  }
}
