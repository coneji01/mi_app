import 'package:flutter/material.dart';

class EstadisticasScreen extends StatelessWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Wrap( // ⬅️ ahora es const
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(title: 'Clientes', value: '—'),
            _StatCard(title: 'Préstamos activos', value: '—'),
            _StatCard(title: 'Balance pendiente', value: 'RD\$ —'),
            _StatCard(title: 'Cuotas vencidas', value: '—'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Tip: aquí puedes conectar métricas reales de la BD cuando gustes.',
          style: text.bodyMedium,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
