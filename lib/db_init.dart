// Selecciona la implementación correcta según la plataforma.
export 'db_init_stub.dart'
    if (dart.library.html) 'db_init_web.dart'
    if (dart.library.io) 'db_init_io.dart';
