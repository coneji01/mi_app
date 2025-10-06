CREATE TABLE IF NOT EXISTS pagos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha TEXT NOT NULL,               -- ISO8601
  monto REAL NOT NULL,
  tipo TEXT NOT NULL,                -- cuota | capital | interes | mora | seguro | gastos | otros
  forma TEXT,
  caja TEXT,
  comentario TEXT,
  fotoPath TEXT,
  prestamoId INTEGER,
  descuento REAL DEFAULT 0,
  otros REAL DEFAULT 0,
  cliente TEXT
);

