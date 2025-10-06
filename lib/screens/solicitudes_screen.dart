import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class SolicitudesScreen extends StatelessWidget {
  const SolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[]; // conecta a tu DB

    return Scaffold(
      drawer: AppDrawer(current: AppSection.solicitudes),
      appBar: AppBar(title: const Text('Solicitudes')),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Sin solicitudes por ahora.\nConéctalo a tu base de datos para verlas aquí.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final it = items[index];
                return ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(it['titulo'] ?? 'Solicitud'),
                  subtitle: Text(it['detalle'] ?? ''),
                  trailing: Text(it['estado'] ?? 'pendiente'),
                );
              },
            ),
    );
  }
}

