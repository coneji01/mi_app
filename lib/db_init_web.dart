import 'package:sqflite_common/sqlite_api.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// En Web usar la factory web (¡es una variable, no una función!)
Future<void> initDbFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
