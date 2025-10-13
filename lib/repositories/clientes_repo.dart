import '../services/api_client.dart';
import '../models/cliente.dart';

class ClientesRepo {
  final ApiClient api;
  ClientesRepo(this.api);

  Future<List<Cliente>> listar({String? search}) async {
    final l = await api.listClientes(search: search);
    return l.map((e) => Cliente.fromJson(e)).toList();
  }

  Future<Cliente> crear(Cliente c) async {
    final m = await api.createCliente(c.toJson());
    return Cliente.fromJson(m);
  }

  Future<Cliente> actualizar(Cliente c) async {
    if (c.id == null) throw Exception('Cliente sin id');
    final m = await api.updateCliente(c.id!, c.toJson());
    return Cliente.fromJson(m);
  }

  Future<void> eliminar(int id) => api.deleteCliente(id);
}
