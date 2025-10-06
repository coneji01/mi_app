import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class PagosScreen extends StatelessWidget {
  const PagosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ← Drawer visible en esta pantalla
      drawer: const AppDrawer(current: AppSection.pagos),

      appBar: AppBar(
        title: const Text('Pagos'),
        centerTitle: false,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Pagos'),
                  subtitle: const Text('Listado / gestión de pagos'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarPagoScreen()));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              
              // Ejemplo placeholder:
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Pago #0001'),
                  subtitle: const Text('Cliente: Juan Pérez • RD\$ 1,200.00'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo pago'),
      ),
    );
  }
}
