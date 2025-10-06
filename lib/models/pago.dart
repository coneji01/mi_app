class Pago {
  final int? id;
  final int prestamoId;
  final String fecha;        // ISO-8601
  final double monto;
  final double otros;
  final double descuento;
  final String nota;
  final String creadoEn;     // ISO-8601
  final String tipo;         // 'capital' | 'interes' | 'mora' | 'seguro' | 'otros' | 'gastos'

  Pago({
    this.id,
    required this.prestamoId,
    required this.fecha,
    required this.monto,
    this.otros = 0,
    this.descuento = 0,
    this.nota = '',
    required this.creadoEn,
    this.tipo = 'capital',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prestamoId': prestamoId,
      'fecha': fecha,
      'monto': monto,
      'otros': otros,
      'descuento': descuento,
      'nota': nota,
      'creadoEn': creadoEn,
      'tipo': tipo,
    };
  }

  factory Pago.fromMap(Map<String, dynamic> map) {
    return Pago(
      id: map['id'] as int?,
      prestamoId: map['prestamoId'] as int,
      fecha: map['fecha'] as String,
      monto: (map['monto'] as num).toDouble(),
      otros: (map['otros'] as num?)?.toDouble() ?? 0,
      descuento: (map['descuento'] as num?)?.toDouble() ?? 0,
      nota: map['nota'] ?? '',
      creadoEn: map['creadoEn'] as String,
      tipo: (map['tipo'] as String?)?.toLowerCase() ?? 'capital',
    );
  }
}
