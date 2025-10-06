import 'package:flutter/material.dart';
import 'app_drawer.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final AppSection? current;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.current,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: true, // muestra el botón hamburguesa
        actions: actions,
      ),
      drawer: AppDrawer(current: current), // ← único Drawer reutilizable
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
