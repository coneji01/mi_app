import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton con ChangeNotifier para exponer y persistir la visibilidad
/// de los campos del formulario "Nuevo Cliente".
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  // === Claves de SharedPreferences ===
  static const _kShowTelefono          = 'show_telefono';
  static const _kShowCedula            = 'show_cedula';
  static const _kShowDireccion         = 'show_direccion';
  static const _kShowEmpresa           = 'show_empresa';
  static const _kShowIngresos          = 'show_ingresos';
  static const _kShowEstadoCivil       = 'show_estado_civil';
  static const _kShowDependientes      = 'show_dependientes';
  static const _kShowDireccionTrabajo  = 'show_direccion_trabajo';
  static const _kShowPuestoTrabajo     = 'show_puesto_trabajo';
  static const _kShowMesesTrabajando   = 'show_meses_trabajando';
  static const _kShowTelefonoTrabajo   = 'show_telefono_trabajo';

  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  // === Estado en memoria (defaults = true) ===
  bool _showTelefono         = true;
  bool _showCedula           = true;
  bool _showDireccion        = true;
  bool _showEmpresa          = true;
  bool _showIngresos         = true;
  bool _showEstadoCivil      = true;
  bool _showDependientes     = true;
  bool _showDireccionTrabajo = true;
  bool _showPuestoTrabajo    = true;
  bool _showMesesTrabajando  = true;
  bool _showTelefonoTrabajo  = true;

  // === Getters públicos ===
  bool get showTelefono         => _showTelefono;
  bool get showCedula           => _showCedula;
  bool get showDireccion        => _showDireccion;
  bool get showEmpresa          => _showEmpresa;
  bool get showIngresos         => _showIngresos;
  bool get showEstadoCivil      => _showEstadoCivil;
  bool get showDependientes     => _showDependientes;
  bool get showDireccionTrabajo => _showDireccionTrabajo;
  bool get showPuestoTrabajo    => _showPuestoTrabajo;
  bool get showMesesTrabajando  => _showMesesTrabajando;
  bool get showTelefonoTrabajo  => _showTelefonoTrabajo;

  /// Llama a esto al inicio de la app (por ejemplo en main) o el primer uso.
  Future<void> ensureInitialized() {
    _initFuture ??= _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    _showTelefono         = _prefs!.getBool(_kShowTelefono)         ?? _showTelefono;
    _showCedula           = _prefs!.getBool(_kShowCedula)           ?? _showCedula;
    _showDireccion        = _prefs!.getBool(_kShowDireccion)        ?? _showDireccion;
    _showEmpresa          = _prefs!.getBool(_kShowEmpresa)          ?? _showEmpresa;
    _showIngresos         = _prefs!.getBool(_kShowIngresos)         ?? _showIngresos;
    _showEstadoCivil      = _prefs!.getBool(_kShowEstadoCivil)      ?? _showEstadoCivil;
    _showDependientes     = _prefs!.getBool(_kShowDependientes)     ?? _showDependientes;
    _showDireccionTrabajo = _prefs!.getBool(_kShowDireccionTrabajo) ?? _showDireccionTrabajo;
    _showPuestoTrabajo    = _prefs!.getBool(_kShowPuestoTrabajo)    ?? _showPuestoTrabajo;
    _showMesesTrabajando  = _prefs!.getBool(_kShowMesesTrabajando)  ?? _showMesesTrabajando;
    _showTelefonoTrabajo  = _prefs!.getBool(_kShowTelefonoTrabajo)  ?? _showTelefonoTrabajo;

    notifyListeners();
  }

  // === Setters con persistencia ===
  Future<void> setShowTelefono(bool v) async {
    _showTelefono = v; await _prefs?.setBool(_kShowTelefono, v); notifyListeners();
  }
  Future<void> setShowCedula(bool v) async {
    _showCedula = v; await _prefs?.setBool(_kShowCedula, v); notifyListeners();
  }
  Future<void> setShowDireccion(bool v) async {
    _showDireccion = v; await _prefs?.setBool(_kShowDireccion, v); notifyListeners();
  }
  Future<void> setShowEmpresa(bool v) async {
    _showEmpresa = v; await _prefs?.setBool(_kShowEmpresa, v); notifyListeners();
  }
  Future<void> setShowIngresos(bool v) async {
    _showIngresos = v; await _prefs?.setBool(_kShowIngresos, v); notifyListeners();
  }
  Future<void> setShowEstadoCivil(bool v) async {
    _showEstadoCivil = v; await _prefs?.setBool(_kShowEstadoCivil, v); notifyListeners();
  }
  Future<void> setShowDependientes(bool v) async {
    _showDependientes = v; await _prefs?.setBool(_kShowDependientes, v); notifyListeners();
  }
  Future<void> setShowDireccionTrabajo(bool v) async {
    _showDireccionTrabajo = v; await _prefs?.setBool(_kShowDireccionTrabajo, v); notifyListeners();
  }
  Future<void> setShowPuestoTrabajo(bool v) async {
    _showPuestoTrabajo = v; await _prefs?.setBool(_kShowPuestoTrabajo, v); notifyListeners();
  }
  Future<void> setShowMesesTrabajando(bool v) async {
    _showMesesTrabajando = v; await _prefs?.setBool(_kShowMesesTrabajando, v); notifyListeners();
  }
  Future<void> setShowTelefonoTrabajo(bool v) async {
    _showTelefonoTrabajo = v; await _prefs?.setBool(_kShowTelefonoTrabajo, v); notifyListeners();
  }
}
