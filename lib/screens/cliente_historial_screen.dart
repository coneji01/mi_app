import 'package:flutter/material.dart';
import '../data/repository.dart';
import 'prestamo_historial_screen.dart';

class ClienteHistorialScreen extends StatefulWidget {
  final int clienteId;
  final String? clienteNombre;

  const ClienteHistorialScreen({
    super.key,
    required this.clienteId,
    this.clienteNombre,
  });

  @override
  State<ClienteHistorialScreen> createState() => _ClienteHistorialScreenState();
}

class _ClienteHistorialScreenState extends State<ClienteHistorialScreen> {
  final _repo = Repository.i;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _prestamos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final rows = await _repo.prestamosPorCliente(widget.clienteId);
      if (!mounted) return;
      setState(() {
        _prestamos = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Helper para manejar claves posibles (camelCase / snake_case)
  T? _first<T>(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k] as T;
    }
    return null;
  }

  String _money(num n) => 'RD\$${n.toStringAsFixed(2)}';

  // Formateador de fecha para mostrar solo AAAA-MM-DD
  String _formatFecha(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty) return '—';
    try {
      // Detecta si es formato completo ISO (con hora)
      if (s.contains('T')) {
        return s.split('T').first; // corta antes de la T
      }
      // Si viene con espacio y hora (YYYY-MM-DD HH:MM:SS)
      if (s.contains(' ')) {
        return s.split(' ').first;
      }
      // Si ya está limpio (YYYY-MM-DD)
      return s;
    } catch (_) {
      return s;
    }
  }

  // Retorna texto con color según estado del préstamo
  Widget _buildEstadoTag(String estado) {
    Color color;
    switch (estado.toLowerCase()) {
      case 'saldado':
        color = Colors.blue;
        break;
      case 'incobrable':
        color = Colors.red;
        break;
      default:
        color = Colors.green; // activo
    }

    return Text(
      estado.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.clienteNombre != null
        ? 'Historial de ${widget.clienteNombre}'
        : 'Historial de préstamos';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _prestamos.isEmpty
                  ? const Center(child: Text('Sin préstamos registrados para este cliente.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _prestamos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _prestamos[i];

                        final id = _first<int>(p, ['id']) ?? 0;
                        final monto = _first<num>(p, ['monto']) ?? 0;
                        final tasaStr = (_first<num>(p, ['interes']) ??
                                _first<num>(p, ['tasa']) ??
                                0)
                            .toString();
                        final cuotas = _first<int>(
                                p, ['cuotasTotales', 'cuotas_totales', 'cuotas']) ??
                            0;
                        final modalidad =
                            _first<String>(p, ['modalidad']) ?? 'Mensual';
                        final fechaInicioRaw = _first<String>(
                                p, ['fechaInicio', 'fecha_inicio']) ??
                            '';
                        final fechaInicio = _formatFecha(fechaInicioRaw);
                        final estado =
                            _first<String>(p, ['estado', 'status']) ?? 'Activo';

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.request_page, size: 32),
                            title: Text(
                              'Préstamo #$id • ${_money(monto)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tasa: $tasaStr% • Cuotas: $cuotas • $modalidad\nInicio: $fechaInicio',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                _buildEstadoTag(estado),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PrestamoHistorialScreen(prestamoId: id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
