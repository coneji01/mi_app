// lib/routes/nav.dart
import 'package:flutter/material.dart';

// SOLUCIÓN: Usamos la ruta absoluta del paquete y el alias 'pd'
// ⚠️ AJUSTA 'mi_app' si el nombre de tu proyecto es diferente.
import 'package:mi_app/screens/prestamo_detalle_screen.dart' as pd;

/// Navega al detalle de préstamo y devuelve el resultado del pop (si lo hay)
Future<T?> pushPrestamoDetalle<T>(
 BuildContext context, {
 required int prestamoId,
 String? clienteNombre,
}) {
 return Navigator.of(context).push<T>(
 MaterialPageRoute(
 // Usamos el alias para acceder a la clase
 builder: (_) => pd.PrestamoDetalleScreen( 
 prestamoId: prestamoId,
 clienteNombre: clienteNombre,
 ),
 ),
 );
}