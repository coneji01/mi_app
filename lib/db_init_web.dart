import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: usar la factory del runtime FFI para navegador.
Future<void> initDbFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
