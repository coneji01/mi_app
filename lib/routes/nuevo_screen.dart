import 'package:flutter/material.dart';

class NuevoScreen extends StatelessWidget {
  const NuevoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionTile(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Nuevo cliente',
          subtitle: 'Registra un cliente con sus datos básicos.',
          onTap: () {
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Acción: Nuevo cliente')),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.request_quote_outlined,
          title: 'Nuevo préstamo',
          subtitle: 'Crea un préstamo y define su modalidad.',
          onTap: () {
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Acción: Nuevo préstamo')),
            );
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
