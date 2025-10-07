// lib/screens/nuevo_prestamo_screen.dart
import 'package:flutter/material.dart';
import '../data/db_service.dart';
import '../models/prestamo.dart';

class NuevoPrestamoScreen extends StatefulWidget {
  // Compatibilidad con ClienteDetalleScreen / Calculadora
  final dynamic cliente;        // objeto Cliente o Map (opcional)
  final dynamic propuesta;      // PrestamoPropuesta o Map (opcional)

  // Alternativas (por constructor o arguments)
  final int? clienteId;
  final String? clienteNombre;

  const NuevoPrestamoScreen({
    super.key,
    this.cliente,
    this.propuesta,
    this.clienteId,
    this.clienteNombre,
  });

  @override
  State<NuevoPrestamoScreen> createState() => _NuevoPrestamoScreenState();
}

class _NuevoPrestamoScreenState extends State<NuevoPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DbService.instance;

  // Controllers
  final _montoCtrl = TextEditingController();
  final _interesCtrl = TextEditingController();        // % por periodo
  final _cuotasTotalesCtrl = TextEditingController();
  final _totalAPagarCtrl = TextEditingController();    // puede autocalcularse o editarse
  final _tipoAmortizacionCtrl = TextEditingController(text: 'Interés Fijo');

  // Modalidad
  final List<String> _modalidades = const ['Semanal', 'Quincenal', 'Mensual'];
  String _modalidad = 'Quincenal';

  // Fecha de inicio
  DateTime _fechaInicio = DateTime.now();
  final _fechaInicioCtrl = TextEditingController();

  // Cliente
  int? _clienteId;
  String? _clienteNombre;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fechaInicioCtrl.text = _fmtFecha(_fechaInicio);
    // Defaults amables
    _interesCtrl.text = '0';
    _cuotasTotalesCtrl.text = '1';

    // Prellenado desde propuesta si vino por constructor
    _prefillDesdePropuesta(widget.propuesta);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1) Args de la ruta (pueden traer cliente/propuesta)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _clienteId ??= (args['clienteId'] ?? args['id']) as int?;
      _clienteNombre ??=
          args['clienteNombre'] as String? ?? args['nombre'] as String?;
      if (args.containsKey('propuesta')) {
        _prefillDesdePropuesta(args['propuesta']);
      }

      // objeto cliente completo
      if (args['cliente'] != null && _clienteId == null) {
        final c = args['cliente'];
        try {
          _clienteId = (c.id as int?);
        } catch (_) {}
        try {
          if (_clienteId == null && c is Map) _clienteId = c['id'] as int?;
        } catch (_) {}
        _clienteNombre ??= _nombreClienteFrom(c);
      }
    } else if (args is int) {
      _clienteId ??= args;
    }

    // 2) Props directas por constructor
    _clienteId ??= widget.clienteId;
    _clienteNombre ??= widget.clienteNombre;

    // 3) Objeto `cliente` pasado por constructor
    if (_clienteId == null && widget.cliente != null) {
      final c = widget.cliente;
      try {
        _clienteId = (c.id as int?);
      } catch (_) {}
      try {
        if (_clienteId == null && c is Map) _clienteId = c['id'] as int?;
      } catch (_) {}
      _clienteNombre ??= _nombreClienteFrom(c);
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _interesCtrl.dispose();
    _cuotasTotalesCtrl.dispose();
    _totalAPagarCtrl.dispose();
    _tipoAmortizacionCtrl.dispose();
    _fechaInicioCtrl.dispose();
    super.dispose();
  }

  // ================== Helpers ==================
  String _fmtFecha(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _pickFechaInicio() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Elige la fecha de inicio',
    );
    if (picked != null) {
      setState(() {
        _fechaInicio = DateTime(picked.year, picked.month, picked.day);
        _fechaInicioCtrl.text = _fmtFecha(_fechaInicio);
      });
    }
  }

  String? _calcularProximoPago(DateTime inicio, String modalidad) {
    final mod = modalidad.toLowerCase();
    Duration paso;
    if (mod.contains('seman')) {
      paso = const Duration(days: 7);
    } else if (mod.contains('mens')) {
      paso = const Duration(days: 30);
    } else {
      paso = const Duration(days: 14); // quincenal
    }
    return inicio.add(paso).toIso8601String();
  }

  double _asDouble(String? s, [double fb = 0]) {
    if (s == null || s.trim().isEmpty) return fb;
    return double.tryParse(s.replaceAll(',', '.')) ?? fb;
  }

  int _asInt(String? s, [int fb = 0]) {
    if (s == null || s.trim().isEmpty) return fb;
    return int.tryParse(s) ?? fb;
  }

  String? _nombreClienteFrom(dynamic c) {
    try {
      final n = (c.nombre as String?) ?? (c['nombre'] as String?);
      final a = (c.apellido as String?) ?? (c['apellido'] as String?);
      final full = '${n ?? ''} ${a ?? ''}'.trim();
      return full.isEmpty ? null : full;
    } catch (_) {
      return null;
    }
  }

  // ----- PREFILL ROBUSTO -----
  void _prefillDesdePropuesta(dynamic p) {
    if (p == null) return;

    num? _getNum(dynamic src, List<String> names) {
      if (src is Map) {
        for (final k in names) {
          final v = src[k];
          if (v != null) return v as num?;
        }
      } else {
        for (final k in names) {
          try {
            switch (k) {
              case 'monto':
                return (src as dynamic).monto as num?;
              case 'principal':
                return (src as dynamic).principal as num?;
              case 'capital':
                return (src as dynamic).capital as num?;
              case 'interes':
                return (src as dynamic).interes as num?;
              case 'tasa':
                return (src as dynamic).tasa as num?;
              case 'tasaInteres':
                return (src as dynamic).tasaInteres as num?;
              case 'cuotasTotales':
                return (src as dynamic).cuotasTotales as num?;
              case 'cuotas':
                return (src as dynamic).cuotas as num?;
              case 'numCuotas':
                return (src as dynamic).numCuotas as num?;
              case 'numeroCuotas':
                return (src as dynamic).numeroCuotas as num?;
              case 'periodos':
                return (src as dynamic).periodos as num?;
              case 'n':
                return (src as dynamic).n as num?;
              case 'totalAPagar':
                return (src as dynamic).totalAPagar as num?;
              case 'total':
                return (src as dynamic).total as num?;
              case 'montoTotal':
                return (src as dynamic).montoTotal as num?;
            }
          } catch (_) {}
        }
      }
      return null;
    }

    String? _getStr(dynamic src, List<String> names) {
      if (src is Map) {
        for (final k in names) {
          final v = src[k];
          if (v != null) return v.toString();
        }
      } else {
        for (final k in names) {
          try {
            switch (k) {
              case 'modalidad':
                return (src as dynamic).modalidad?.toString();
              case 'frecuencia':
                return (src as dynamic).frecuencia?.toString();
              case 'periodicidad':
                return (src as dynamic).periodicidad?.toString();
              case 'tipoAmortizacion':
                return (src as dynamic).tipoAmortizacion?.toString();
              case 'amortizacion':
                return (src as dynamic).amortizacion?.toString();
            }
          } catch (_) {}
        }
      }
      return null;
    }

    // monto
    final num? monto = _getNum(p, ['monto', 'principal', 'capital']);
    if (monto != null) _montoCtrl.text = monto.toString();

    // interés % por periodo
    final num? interes =
        _getNum(p, ['interes', 'tasa', 'tasaInteres']);
    if (interes != null) _interesCtrl.text = interes.toString();

    // cuotas
    final num? cuotas = _getNum(
        p, ['cuotasTotales', 'cuotas', 'numCuotas', 'numeroCuotas', 'periodos', 'n']);
    if (cuotas != null) _cuotasTotalesCtrl.text = cuotas.toInt().toString();

    // modalidad (opcional)
    final String? modalidad =
        _getStr(p, ['modalidad', 'frecuencia', 'periodicidad']);
    if (modalidad != null && modalidad.trim().isNotEmpty) _modalidad = modalidad;

    // tipo amortización (opcional)
    final String? tipo =
        _getStr(p, ['tipoAmortizacion', 'amortizacion']);
    if (tipo != null && tipo.trim().isNotEmpty) {
      _tipoAmortizacionCtrl.text = tipo;
    }

    // total (si viene)
    final num? total = _getNum(p, ['totalAPagar', 'total', 'montoTotal']);
    if (total != null) _totalAPagarCtrl.text = total.toString();

    // Si no vino total, lo calculamos
    if (_totalAPagarCtrl.text.trim().isEmpty) {
      _recalcularTotal();
    } else {
      setState(() {}); // refrescar UI
    }
  }

  void _recalcularTotal() {
    final m = _asDouble(_montoCtrl.text);
    final i = _asDouble(_interesCtrl.text) / 100.0;
    final n = _asInt(_cuotasTotalesCtrl.text, 1);
    final total = (m + (m * i * n)).clamp(0, double.infinity);
    _totalAPagarCtrl.text =
        total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2);
    setState(() {});
  }

  // ================== Guardar ==================
  Future<void> _guardar() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero un cliente válido.')),
      );
      return;
    }
    if (!form.validate()) return;

    final monto = _asDouble(_montoCtrl.text);
    final interes = _asDouble(_interesCtrl.text);
    final cuotasTotales = _asInt(_cuotasTotalesCtrl.text, 1);
    final totalAPagar = _asDouble(_totalAPagarCtrl.text);

    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor que 0.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final p = Prestamo(
        clienteId: _clienteId!,
        monto: monto,
        balancePendiente: totalAPagar,
        totalAPagar: totalAPagar,
        cuotasTotales: cuotasTotales,
        cuotasPagadas: 0,
        interes: interes,
        modalidad: _modalidad,
        tipoAmortizacion: _tipoAmortizacionCtrl.text.trim().isEmpty
            ? 'Interés Fijo'
            : _tipoAmortizacionCtrl.text.trim(),
        fechaInicio: _fechaInicio.toIso8601String(),      // ISO-8601
        proximoPago: _calcularProximoPago(_fechaInicio, _modalidad),
      );

      final newId = await _db.crearPrestamo(p);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préstamo asignado (ID $newId)')),
      );
      Navigator.pop(context, newId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final clienteLabel = _clienteNombre == null
        ? 'Cliente: #${_clienteId ?? '?'}'
        : 'Cliente: $_clienteNombre';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo préstamo'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(clienteLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Fecha de inicio
              TextFormField(
                controller: _fechaInicioCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de inicio',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
                onTap: _pickFechaInicio,
                validator: (_) =>
                    _fechaInicioCtrl.text.isEmpty ? 'Seleccione la fecha de inicio' : null,
              ),
              const SizedBox(height: 12),

              // Monto
              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: 'RD\$ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalcularTotal(),
                validator: (v) {
                  final n = _asDouble(v);
                  if (n <= 0) return 'Ingrese un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Interés % por periodo
              TextFormField(
                controller: _interesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interés (%) por periodo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalcularTotal(),
                validator: (v) {
                  final n = _asDouble(v);
                  if (n < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Cuotas totales
              TextFormField(
                controller: _cuotasTotalesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cuotas totales',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalcularTotal(),
                validator: (v) {
                  final n = _asInt(v, 0);
                  if (n <= 0) return 'Debe ser mayor que 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Modalidad
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Modalidad',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _modalidad,
                    isExpanded: true,
                    items: _modalidades
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _modalidad = v);
                      _recalcularTotal(); // recalcular si cambias modalidad
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tipo amortización
              TextFormField(
                controller: _tipoAmortizacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipo de amortización',
                  hintText: 'Interés Fijo / Francés / Otro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Total a pagar
              TextFormField(
                controller: _totalAPagarCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total a pagar',
                  prefixText: 'RD\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = _asDouble(v);
                  if (n <= 0) return 'Ingrese un total válido';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text('Asignar préstamo'),
                  onPressed: _saving ? null : _guardar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
