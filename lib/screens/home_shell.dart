import 'package:flutter/material.dart';

// Pantallas/tab
import 'pagos_screen.dart';
import 'inicio_screen.dart';
import 'nuevo_cliente_screen.dart';

class HomeShell extends StatefulWidget {
  // 0=CxC, 1=Inicio, 2=Nuevo
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 1});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  // Orden de tabs: 0=CxC, 1=Inicio, 2=Nuevo
  final List<Widget> _pages = const <Widget>[
    PagosScreen(),          // contenido (sin Scaffold)
    InicioScreen(),         // contenido (tu dashboard)
    NuevoClienteScreen(),   // contenido (form nuevo cliente)
  ];

  final List<String> _titles = const <String>[
    'CxC', 'Inicio', 'Nuevo',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex; // ← arrancar en Inicio
  }

  void _goTab(int i) {
    setState(() => _index = i);
    Navigator.pop(context); // cerrar drawer
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('Joel Wifi Dominicana',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            // Importante: estos ítems SOLO cambian de pestaña
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('CxC'),
              selected: _index == 0,
              onTap: () => _goTab(0),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Inicio'),
              selected: _index == 1,
              onTap: () => _goTab(1),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Nuevo'),
              selected: _index == 2,
              onTap: () => _goTab(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Salir'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: _buildDrawer(),                       // ← Drawer visible SIEMPRE aquí
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'CxC',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_alt_1_outlined),
            label: 'Nuevo',
          ),
        ],
      ),
    );
  }
}
