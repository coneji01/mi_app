import 'dart:math';

/// Tipos soportados
enum TipoAmortizacion {
  interesFijo,      // interés sobre principal inicial, cuota = interes fijo + (P/n)
  cuotaFija,        // francés: cuota constante
  disminuirCuota,   // alemán: capital fijo => cuota decrece
  capitalAlFinal,   // bullet: solo intereses y capital en la última
}

/// Item del plan
class CuotaItem {
  final int numero;
  final DateTime fecha;
  final double cuota;    // total a pagar ese período
  final double capital;  // parte de capital
  final double interes;  // parte de interés
  final double saldo;    // saldo después de pagar

  CuotaItem({
    required this.numero,
    required this.fecha,
    required this.cuota,
    required this.capital,
    required this.interes,
    required this.saldo,
  });
}

class PlanAmortizacion {
  final List<CuotaItem> cuotas;
  final double totalInteres;
  final double totalPagar;

  const PlanAmortizacion({
    required this.cuotas,
    required this.totalInteres,
    required this.totalPagar,
  });
}

/// Suma períodos para fechas (Semanal 7d, Quincenal 14d, Mensual 30d)
DateTime _addPeriodo(DateTime base, String modalidad, int k) {
  final low = modalidad.toLowerCase();
  int dias;
  if (low.contains('seman')) {
    dias = 7;
  } else if (low.contains('mens')) {
    dias = 30;
  } else {
    dias = 14; // quincenal por defecto
  }
  return base.add(Duration(days: dias * k));
}

/// Genera plan
/// - [tasa] es % por período (no anual)
PlanAmortizacion generarPlan({
  required TipoAmortizacion tipo,
  required double monto,
  required double tasa,         // % por período
  required int cuotasTot,
  required DateTime inicio,
  required String modalidad,
}) {
  assert(monto > 0 && cuotasTot > 0);

  final r = tasa / 100.0; // tasa por periodo
  final List<CuotaItem> out = [];
  double saldo = monto;
  double acumInteres = 0;
  double acumCuotas = 0;

  switch (tipo) {
    case TipoAmortizacion.interesFijo: {
      final interesFijo = monto * r;
      final amortFija   = monto / cuotasTot;
      for (int k = 1; k <= cuotasTot; k++) {
        final interes = interesFijo;
        final capital = (k == cuotasTot) ? saldo : amortFija; // ajuste final
        final cuota = interes + capital;
        saldo = (saldo - capital).clamp(0, double.maxFinite);

        final fecha = _addPeriodo(inicio, modalidad, k);
        out.add(CuotaItem(numero: k, fecha: fecha,
          cuota: cuota, capital: capital, interes: interes, saldo: saldo));
        acumInteres += interes;
        acumCuotas  += cuota;
      }
      break;
    }

    case TipoAmortizacion.cuotaFija: { // francés
      final denom = r == 0 ? 1.0 : (1 - pow(1 + r, -cuotasTot));
      final cuota = r == 0 ? (monto / cuotasTot) : (monto * r / denom);
      for (int k = 1; k <= cuotasTot; k++) {
        final interes = saldo * r;
        final capital = (k == cuotasTot) ? saldo : (cuota - interes);
        final realCuota = (k == cuotasTot) ? (capital + interes) : cuota;
        saldo = (saldo - capital).clamp(0, double.maxFinite);

        final fecha = _addPeriodo(inicio, modalidad, k);
        out.add(CuotaItem(numero: k, fecha: fecha,
          cuota: realCuota, capital: capital, interes: interes, saldo: saldo));
        acumInteres += interes;
        acumCuotas  += realCuota;
      }
      break;
    }

    case TipoAmortizacion.disminuirCuota: { // alemán
      final amortConst = monto / cuotasTot;
      for (int k = 1; k <= cuotasTot; k++) {
        final interes = saldo * r;
        final capital = (k == cuotasTot) ? saldo : amortConst;
        final cuota = capital + interes;
        saldo = (saldo - capital).clamp(0, double.maxFinite);

        final fecha = _addPeriodo(inicio, modalidad, k);
        out.add(CuotaItem(numero: k, fecha: fecha,
          cuota: cuota, capital: capital, interes: interes, saldo: saldo));
        acumInteres += interes;
        acumCuotas  += cuota;
      }
      break;
    }

    case TipoAmortizacion.capitalAlFinal: { // bullet
      final interesPeriodo = monto * r;
      for (int k = 1; k <= cuotasTot; k++) {
        final ultima = (k == cuotasTot);
        final interes = interesPeriodo;
        final capital = ultima ? monto : 0.0;
        final cuota   = interes + capital;
        saldo = ultima ? 0.0 : saldo;

        final fecha = _addPeriodo(inicio, modalidad, k);
        out.add(CuotaItem(numero: k, fecha: fecha,
          cuota: cuota, capital: capital, interes: interes, saldo: saldo));
        acumInteres += interes;
        acumCuotas  += cuota;
      }
      break;
    }
  }

  return PlanAmortizacion(
    cuotas: out,
    totalInteres: acumInteres,
    totalPagar: acumCuotas,
  );
}

/// Helpers para DB (campo TEXT)
String tipoAmortizacionToDb(TipoAmortizacion t) {
  switch (t) {
    case TipoAmortizacion.interesFijo:     return 'InteresFijo';
    case TipoAmortizacion.cuotaFija:       return 'CuotaFija';
    case TipoAmortizacion.disminuirCuota:  return 'DisminuirCuota';
    case TipoAmortizacion.capitalAlFinal:  return 'CapitalAlFinal';
  }
}

TipoAmortizacion tipoAmortizacionFromDb(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'interesfijo':     return TipoAmortizacion.interesFijo;
    case 'cuotafija':       return TipoAmortizacion.cuotaFija;
    case 'disminuircuota':  return TipoAmortizacion.disminuirCuota;
    case 'capitalalfinal':  return TipoAmortizacion.capitalAlFinal;
    default: return TipoAmortizacion.interesFijo;
  }
}
