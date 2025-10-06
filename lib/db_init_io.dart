import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// En Android/iOS se usa sqflite normal (NO FFI).
// En desktop (Windows/macOS/Linux) sí usamos FFI.
Future<void> initDbFactory() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return; // nada que hacer: sqflite ya está listo en móvil
  }
  // Desktop:
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
