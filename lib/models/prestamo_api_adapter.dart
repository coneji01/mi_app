// lib/models/prestamo_api_adapter.dart
import '../models/prestamo.dart';

/// Extensión para serializar TU modelo Prestamo hacia el backend (snake_case).
extension PrestamoApiAdapter on Prestamo {
  Map<String, dynamic> toApiMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'monto': monto,
      'interes': interes,
      'cuotas': cuotasTotales,
      if (cuotasPagadas != null) 'cuotas_pagadas': cuotasPagadas,
      'modalidad': modalidad,
      'tipo_amortizacion': tipoAmort, // tu modelo usa tipoAmort
      'fecha_inicio': fechaInicio.toIso8601String(),
      if (proximoPago != null) 'proximo_pago': proximoPago!.toIso8601String(),
      if (estado != null) 'estado': estado,
      if (creadoEn != null) 'creado_en': creadoEn!.toIso8601String(),
      // Si necesitas enviar saldos, puedes mapearlos aquí:
      if (balancePendiente != null) 'saldo_capital': balancePendiente,
      if (totalAPagar != null) 'total_a_pagar': totalAPagar,
    };
  }
}

/// Construye TU modelo desde el JSON del backend (tolerante con claves/formatos).
Prestamo prestamoFromApiMap(Map<String, dynamic> map) {
  int? asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  DateTime? asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) {
      // acepta epoch s/ms
      return v > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(v)
          : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String) {
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  final id            = asInt(map['id'] ?? map['ID']);
  final clienteId     = asInt(map['cliente_id'] ?? map['clienteId'] ?? map['cliente']) ?? 0;
  final monto         = asDouble(map['monto'] ?? map['capital']) ?? 0.0;
  final interes       = asDouble(map['interes'] ?? map['tasa']) ?? 0.0;
  final cuotasTotales = asInt(map['cuotas'] ?? map['cuotasTotales'] ?? map['n_cuotas']) ?? 0;
  final cuotasPagadas = asInt(map['cuotas_pagadas'] ?? map['cuotasPagadas'] ?? map['pagadas']);
  final modalidad     = (map['modalidad'] ?? map['periodicidad'] ?? 'Mensual').toString();
  final tipoAmort     = (map['tipo_amortizacion'] ?? map['tipoAmortizacion'] ?? 'Interés Fijo').toString();
  final fechaInicio   = asDate(map['fecha_inicio'] ?? map['fechaInicio']) ?? DateTime.now();
  final proximoPago   = asDate(map['proximo_pago'] ?? map['proximoPago']);
  final estado        = (map['estado'] ?? map['status'])?.toString();
  final creadoEn      = asDate(map['creado_en'] ?? map['created_at']);

  final balancePendiente = asDouble(map['saldo_capital'] ?? map['balance_pendiente'] ?? map['balancePendiente']);
  final totalAPagar      = asDouble(map['total_a_pagar'] ?? map['totalAPagar']);

  return Prestamo(
    id: id,
    clienteId: clienteId,
    monto: monto,
    balancePendiente: balancePendiente,
    totalAPagar: totalAPagar,
    cuotasTotales: cuotasTotales,
    cuotasPagadas: cuotasPagadas,
    interes: interes,
    modalidad: modalidad,
    tipoAmort: tipoAmort,
    fechaInicio: fechaInicio,
    proximoPago: proximoPago,
    estado: estado,
    creadoEn: creadoEn,
  );
}
