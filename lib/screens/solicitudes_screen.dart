import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/app_drawer.dart';
import '../data/repository.dart';
import '../models/solicitud.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _repo = Repository.i;
  List<Solicitud> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _repo.solicitudes();
      final data = raw
          .map((e) => Solicitud.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error cargando solicitudes: $e';
        _loading = false;
      });
    }
  }

  String _fmtFecha(DateTime dt) => DateFormat('dd/MM/yyyy • hh:mm a').format(dt);

  Future<void> _crearYEnviar() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();

    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enviar solicitud a un número',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (solo dígitos)',
                  hintText: '8091234567',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Crear y elegir envío'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (res != true) return;

    final nombre = nombreCtrl.text.trim().isEmpty ? null : nombreCtrl.text.trim();
    final tel = _soloDigitos(telCtrl.text);

    final created = await _repo.crearSolicitud(nombre: nombre, telefono: tel);
    final s = Solicitud.fromMap(created);
    if (!mounted) return;
    setState(() => _items = [s, ..._items]);

    _accionesEnvio(s);
  }

  String? _soloDigitos(String? raw) {
    if (raw == null) return null;
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? null : d;
  }

  Future<void> _accionesEnvio(Solicitud s) async {
    final msg = 'Hola${s.nombre == null ? '' : ' ${s.nombre}'}.\n'
        'Completa tu solicitud de préstamo aquí:\n${s.urlFormulario}\n\n'
        'Gracias.';

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.whatsapp),
              title: const Text('Enviar por WhatsApp'),
              onTap: () async {
                Navigator.pop(ctx);
                await _openWhatsApp(s.telefono, msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms),
              title: const Text('Enviar por SMS'),
              onTap: () async {
                Navigator.pop(ctx);
                await _openSMS(s.telefono, msg);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar link'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: s.urlFormulario));
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado al portapapeles')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Abrir en navegador'),
              onTap: () async {
                Navigator.pop(ctx);
                await _openUrl(s.urlFormulario);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast('No se pudo abrir el enlace.');
    }
  }

  Future<void> _openWhatsApp(String? phone, String text) async {
    final p = _soloDigitos(phone ?? '');
    final encoded = Uri.encodeComponent(text);
    final uri = p == null
        ? Uri.parse('https://wa.me/?text=$encoded')
        : Uri.parse('https://wa.me/$p?text=$encoded');
    await _openUrl(uri.toString());
  }

  Future<void> _openSMS(String? phone, String text) async {
    final p = _soloDigitos(phone ?? '');
    final uri = p == null
        ? Uri.parse('sms:?body=${Uri.encodeComponent(text)}')
        : Uri.parse('sms:$p?body=${Uri.encodeComponent(text)}');
    await _openUrl(uri.toString());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // cámbialo a AppSection.solicitudes si tienes esa sección en tu Drawer
      drawer: const AppDrawer(current: AppSection.pagos),
      appBar: AppBar(
        title: const Text('Solicitudes'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearYEnviar,
        icon: const Icon(Icons.add),
        label: const Text('Enviar solicitud'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? const Center(child: Text('Aún no hay solicitudes'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 0),
                          itemBuilder: (ctx, i) {
                            final s = _items[i];
                            return ListTile(
                              title: Text(
                                s.nombre?.isNotEmpty == true ? s.nombre! : 'Sin nombre',
                              ),
                              subtitle: Text(
                                '${s.telefono ?? '—'}  •  ${_fmtFecha(s.creadoEn)}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  s.estado,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              onTap: () => _openUrl(s.urlFormulario),
                              onLongPress: () => _accionesEnvio(s),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
