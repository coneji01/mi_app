// lib/screens/nuevo_prestamo_screen.dart
import 'package:flutter/material.dart';
import '../data/repository.dart';

class NuevoPrestamoScreen extends StatefulWidget {
  // Compatibilidad con otras pantallas que puedan pasar datos
  final dynamic cliente;        // objeto Cliente o Map (opcional)
  final dynamic propuesta;      // PrestamoPropuesta o Map (opcional)

  final int? clienteId;         // también por constructor
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

  // Controllers
  final _montoCtrl = TextEditingController();
  final _interesCtrl = TextEditingController(text: '0');        // % por período
  final _cuotasTotalesCtrl = TextEditingController(text: '1');
  final _totalAPagarCtrl = TextEditingController();             // opcional, UI
  final _tipoAmortizacionCtrl = TextEditingController(text: 'Interés Fijo');

  // Modalidad (UI) -> el backend espera: 'semanal' | 'quincenal' | 'mensual'
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
    _prefillDesdePropuesta(widget.propuesta);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 1) Args de la ruta
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _clienteId ??= (args['clienteId'] ?? args['id']) as int?;
      _clienteNombre ??= args['clienteNombre'] as String? ?? args['nombre'] as String?;
      if (args.containsKey('propuesta')) _prefillDesdePropuesta(args['propuesta']);

      if (args['cliente'] != null && _clienteId == null) {
        final c = args['cliente'];
        try { _clienteId = (c.id as int?); } catch (_) {}
        try { _clienteId ??= (c as Map)['id'] as int?; } catch (_) {}
        _clienteNombre ??= _nombreClienteFrom(c);
      }
    } else if (args is int) {
      _clienteId ??= args;
    }

    // 2) Props por constructor
    _clienteId ??= widget.clienteId;
    _clienteNombre ??= widget.clienteNombre;

    // 3) Objeto cliente por constructor
    if (_clienteId == null && widget.cliente != null) {
      final c = widget.cliente;
      try { _clienteId = (c.id as int?); } catch (_) {}
      try { _clienteId ??= (c as Map)['id'] as int?; } catch (_) {}
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

  // Prefill desde una propuesta (si viene de la calculadora)
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
              case 'principal':
              case 'capital':
                return (src as dynamic).monto as num?;
              case 'interes':
              case 'tasa':
              case 'tasaInteres':
                return (src as dynamic).interes as num?;
              case 'cuotasTotales':
              case 'cuotas':
              case 'numCuotas':
              case 'numeroCuotas':
              case 'periodos':
              case 'n':
                return (src as dynamic).cuotasTotales as num?;
              case 'totalAPagar':
              case 'total':
              case 'montoTotal':
                return (src as dynamic).totalAPagar as num?;
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
              case 'frecuencia':
              case 'periodicidad':
                return (src as dynamic).modalidad?.toString();
              case 'tipoAmortizacion':
              case 'amortizacion':
                return (src as dynamic).tipoAmortizacion?.toString();
            }
          } catch (_) {}
        }
      }
      return null;
    }

    final num? monto = _getNum(p, ['monto', 'principal', 'capital']);
    if (monto != null) _montoCtrl.text = monto.toString();

    final num? interes = _getNum(p, ['interes', 'tasa', 'tasaInteres']);
    if (interes != null) _interesCtrl.text = interes.toString();

    final num? cuotas = _getNum(p, ['cuotasTotales', 'cuotas', 'numCuotas', 'numeroCuotas', 'periodos', 'n']);
    if (cuotas != null) _cuotasTotalesCtrl.text = cuotas.toInt().toString();

    final String? modalidad = _getStr(p, ['modalidad', 'frecuencia', 'periodicidad']);
    if (modalidad != null && modalidad.trim().isNotEmpty) _modalidad = modalidad;

    final String? tipo = _getStr(p, ['tipoAmortizacion', 'amortizacion']);
    if (tipo != null && tipo.trim().isNotEmpty) _tipoAmortizacionCtrl.text = tipo;

    final num? total = _getNum(p, ['totalAPagar', 'total', 'montoTotal']);
    if (total != null) _totalAPagarCtrl.text = total.toString();
    setState(() {});
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

  // ================== Guardar (SOLO BACKEND) ==================
  Future<void> _guardar() async {
    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero un cliente válido.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final monto = _asDouble(_montoCtrl.text);
    final interes = _asDouble(_interesCtrl.text);
    final cuotasTotales = _asInt(_cuotasTotalesCtrl.text, 1);

    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe ser mayor que 0.')),
      );
      return;
    }

    // Mapear modalidad UI -> valor API
    final modalidadApi = _modalidad.toLowerCase(); // 'semanal'|'quincenal'|'mensual'

    final body = <String, dynamic>{
      'cliente_id': _clienteId,
      'monto': monto,
      'interes': interes,
      'modalidad': modalidadApi,
      'tipo_amort': _tipoAmortizacionCtrl.text.trim().isEmpty
          ? 'Interés Fijo'
          : _tipoAmortizacionCtrl.text.trim(),
      'cuotas_totales': cuotasTotales,
      'fecha_inicio': _fmtFecha(_fechaInicio), // YYYY-MM-DD
      // Los siguientes los puede calcular el backend; no los enviamos:
      // 'balance_pendiente', 'total_a_pagar', 'cuotas_pagadas', 'proximo_pago'
    };

    setState(() => _saving = true);
    try {
      await Repository.i.crearPrestamo(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préstamo creado ✅')),
      );
      Navigator.pop(context, true); // para que la lista de préstamos recargue
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear préstamo: $e')),
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
      appBar: AppBar(title: const Text('Nuevo préstamo')),
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
                validator: (v) => _asDouble(v) <= 0 ? 'Ingrese un monto válido' : null,
              ),
              const SizedBox(height: 12),

              // Interés % por período
              TextFormField(
                controller: _interesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interés (%) por período',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _recalcularTotal(),
                validator: (v) => _asDouble(v) < 0 ? 'No puede ser negativo' : null,
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
                validator: (v) => _asInt(v, 0) <= 0 ? 'Debe ser mayor que 0' : null,
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
                      _recalcularTotal();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tipo amortización (se envía como tipo_amort)
              TextFormField(
                controller: _tipoAmortizacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipo de amortización',
                  hintText: 'Interés Fijo / Francés / Otro',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Total a pagar (informativo)
              TextFormField(
                controller: _totalAPagarCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total estimado a pagar (informativo)',
                  prefixText: 'RD\$ ',
                  border: OutlineInputBorder(),
                ),
                // no lo validamos ni lo enviamos si tu backend lo calcula
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
