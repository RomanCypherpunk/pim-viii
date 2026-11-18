import 'dart:convert';

import 'package:alunostech_mobile/api.dart';
import 'package:alunostech_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _jwtFalso(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64(payload)}.x';
}

void main() {
  testWidgets('login com credenciais invalidas mostra a mensagem da API', (tester) async {
    final mock = MockClient((_) async => http.Response(jsonEncode({'erro': 'Credenciais inválidas.'}), 401));
    await tester.pumpWidget(AlunosTechApp(api: ApiClient(client: mock)));
    await tester.enterText(find.byKey(const Key('email')), 'x@y.com');
    await tester.enterText(find.byKey(const Key('senha')), 'errada');
    await tester.tap(find.byKey(const Key('entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Credenciais inválidas.'), findsOneWidget);
  });

  testWidgets('login valido abre a lista de tarefas', (tester) async {
    final mock = MockClient((req) async {
      if (req.url.path == '/api/auth/login') {
        return http.Response(jsonEncode({'accessToken': _jwtFalso({'clienteId': 1}), 'nome': 'Dev', 'perfil': 'Desenvolvedor'}), 200);
      }
      if (req.url.path.endsWith('/tarefas')) {
        return http.Response(jsonEncode([{'id': 1, 'titulo': 'Tela de login', 'estado': 2, 'pontos': 3, 'rowVersion': 'AAAAAAAAB9s='}]), 200);
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(AlunosTechApp(api: ApiClient(client: mock)));
    await tester.enterText(find.byKey(const Key('email')), 'dev@alunostech.dev');
    await tester.enterText(find.byKey(const Key('senha')), 'AlunosTech@2026');
    await tester.tap(find.byKey(const Key('entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Dev'), findsOneWidget);
    expect(find.text('Tela de login'), findsOneWidget);
    expect(find.textContaining('Em andamento'), findsOneWidget);
  });

  test('ApiClient.mover sinaliza conflito (HTTP 409)', () async {
    final mock = MockClient((req) async {
      if (req.url.path == '/api/auth/login') {
        return http.Response(jsonEncode({'accessToken': _jwtFalso({}), 'nome': 'Dev', 'perfil': 'x'}), 200);
      }
      return http.Response(jsonEncode({'erro': 'Conflito'}), 409);
    });
    final api = ApiClient(client: mock);
    await api.login('a@b.com', 'x');
    expect(() => api.mover(Tarefa(1, 't', 1, 1, 'AAAAAAAAB9s='), 2),
        throwsA(isA<ApiException>().having((e) => e.conflito, 'conflito', true)));
  });
}
