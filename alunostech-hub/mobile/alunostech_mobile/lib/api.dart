import 'dart:convert';
import 'package:http/http.dart' as http;

/// URL base da API. Em emulador Android use --dart-define=API_URL=http://10.0.2.2:5080
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5080');

class Tarefa {
  Tarefa(this.id, this.titulo, this.estado, this.pontos, this.rowVersion);
  final int id;
  final String titulo;
  final int estado;
  final int pontos;
  final String rowVersion;

  factory Tarefa.fromJson(Map<String, dynamic> j) =>
      Tarefa(j['id'], j['titulo'], j['estado'], j['pontos'], j['rowVersion']);
}

class Chamado {
  Chamado(this.id, this.titulo, this.prioridade, this.prazoSla);
  final int id;
  final String titulo;
  final int prioridade;
  final DateTime prazoSla;

  factory Chamado.fromJson(Map<String, dynamic> j) =>
      Chamado(j['id'], j['titulo'], j['prioridade'], DateTime.parse(j['prazoSla']));
}

class ApiException implements Exception {
  ApiException(this.mensagem, {this.conflito = false});
  final String mensagem;
  final bool conflito;
  @override
  String toString() => mensagem;
}

/// Cliente da API REST (mesmo contrato usado pelo painel web e pelo desktop).
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  String? _token;
  int? clienteId;
  String? nome;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  String _erro(http.Response r) {
    try {
      return (jsonDecode(r.body) as Map)['erro'] as String;
    } catch (_) {
      return 'Falha HTTP ${r.statusCode}';
    }
  }

  Future<void> login(String email, String senha) async {
    final r = await _http.post(Uri.parse('$apiUrl/api/auth/login'),
        headers: _headers, body: jsonEncode({'email': email, 'senha': senha}));
    if (r.statusCode != 200) throw ApiException(_erro(r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _token = j['accessToken'];
    nome = j['nome'];
    // clienteId vem no JWT (payload); o app o usa apenas para pré-preencher o chamado
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(_token!.split('.')[1])));
    clienteId = (jsonDecode(payload) as Map)['clienteId'] as int?;
  }

  Future<List<Tarefa>> tarefas(int projetoId) async {
    final r = await _http.get(Uri.parse('$apiUrl/api/projetos/$projetoId/tarefas'), headers: _headers);
    if (r.statusCode != 200) throw ApiException(_erro(r));
    return (jsonDecode(r.body) as List).map((e) => Tarefa.fromJson(e)).toList();
  }

  Future<void> mover(Tarefa t, int novoEstado) async {
    final r = await _http.patch(Uri.parse('$apiUrl/api/tarefas/${t.id}/mover'),
        headers: _headers, body: jsonEncode({'novoEstado': novoEstado, 'rowVersion': t.rowVersion}));
    if (r.statusCode == 409) throw ApiException(_erro(r), conflito: true);
    if (r.statusCode != 200) throw ApiException(_erro(r));
  }

  Future<List<Chamado>> chamados() async {
    final r = await _http.get(Uri.parse('$apiUrl/api/chamados'), headers: _headers);
    if (r.statusCode != 200) throw ApiException(_erro(r));
    return (jsonDecode(r.body) as List).map((e) => Chamado.fromJson(e)).toList();
  }

  Future<void> abrirChamado(int clienteId, String titulo, int prioridade) async {
    final r = await _http.post(Uri.parse('$apiUrl/api/chamados'),
        headers: _headers,
        body: jsonEncode({'clienteId': clienteId, 'titulo': titulo, 'prioridade': prioridade}));
    if (r.statusCode != 201) throw ApiException(_erro(r));
  }
}
