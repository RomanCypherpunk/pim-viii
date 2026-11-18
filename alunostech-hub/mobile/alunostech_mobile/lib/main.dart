import 'package:flutter/material.dart';
import 'api.dart';

void main() => runApp(const AlunosTechApp());

class AlunosTechApp extends StatelessWidget {
  const AlunosTechApp({super.key, this.api});
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    final cliente = api ?? ApiClient();
    return MaterialApp(
      title: 'Alunos Tech Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F4E79), useMaterial3: true),
      home: LoginPage(api: cliente),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _carregando = false;

  Future<void> _entrar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      await widget.api.login(_email.text.trim(), _senha.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(api: widget.api)));
    } on ApiException catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = 'Não foi possível conectar à API.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
                Text('Alunos Tech Hub', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Acesso de colaboradores e clientes'),
                const SizedBox(height: 24),
                TextField(key: const Key('email'), controller: _email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(key: const Key('senha'), controller: _senha, obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
                if (_erro != null) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text(_erro!, key: const Key('erro'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 16),
                FilledButton(key: const Key('entrar'), onPressed: _carregando ? null : _entrar,
                    child: Text(_carregando ? 'Entrando...' : 'Entrar')),
              ]),
            ),
          ),
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.api});
  final ApiClient api;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Olá, ${api.nome ?? ''}'),
            bottom: const TabBar(tabs: [Tab(text: 'Minhas tarefas'), Tab(text: 'Chamados')]),
          ),
          body: TabBarView(children: [TarefasTab(api: api), ChamadosTab(api: api)]),
        ),
      );
}

const colunas = ['Backlog', 'Planejada', 'Em andamento', 'Em revisão', 'Concluída'];

class TarefasTab extends StatefulWidget {
  const TarefasTab({super.key, required this.api});
  final ApiClient api;
  @override
  State<TarefasTab> createState() => _TarefasTabState();
}

class _TarefasTabState extends State<TarefasTab> {
  late Future<List<Tarefa>> _futuro = widget.api.tarefas(1);

  void _recarregar() => setState(() => _futuro = widget.api.tarefas(1));

  Future<void> _mover(Tarefa t, int novo) async {
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.api.mover(t, novo);
      m.showSnackBar(SnackBar(content: Text('"${t.titulo}" movida para ${colunas[novo]}.')));
    } on ApiException catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.conflito ? 'Conflito: a tarefa mudou. Atualizando a lista.' : e.mensagem)));
    }
    _recarregar();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Tarefa>>(
        future: _futuro,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('${s.error}'));
          final tarefas = s.data!;
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView.separated(
              itemCount: tarefas.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = tarefas[i];
                return ListTile(
                  title: Text(t.titulo),
                  subtitle: Text('${colunas[t.estado]} · ${t.pontos} pts'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.estado > 0) IconButton(tooltip: 'Voltar etapa', icon: const Icon(Icons.arrow_back), onPressed: () => _mover(t, t.estado - 1)),
                    if (t.estado < 4) IconButton(tooltip: 'Avançar etapa', icon: const Icon(Icons.arrow_forward), onPressed: () => _mover(t, t.estado + 1)),
                  ]),
                );
              },
            ),
          );
        },
      );
}

class ChamadosTab extends StatefulWidget {
  const ChamadosTab({super.key, required this.api});
  final ApiClient api;
  @override
  State<ChamadosTab> createState() => _ChamadosTabState();
}

class _ChamadosTabState extends State<ChamadosTab> {
  late Future<List<Chamado>> _futuro = widget.api.chamados();
  static const prioridades = ['', 'Crítica', 'Alta', 'Média', 'Baixa'];

  Future<void> _novo() async {
    final ctrl = TextEditingController();
    final titulo = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abrir chamado'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Título')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Abrir')),
        ],
      ),
    );
    if (titulo == null || titulo.trim().isEmpty) return;
    try {
      await widget.api.abrirChamado(widget.api.clienteId ?? 1, titulo.trim(), 3);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
    setState(() => _futuro = widget.api.chamados());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Novo chamado')),
        body: FutureBuilder<List<Chamado>>(
          future: _futuro,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('${s.error}'));
            final cs = s.data!;
            if (cs.isEmpty) return const Center(child: Text('Nenhum chamado.'));
            return ListView(children: [
              for (final c in cs)
                ListTile(
                  title: Text(c.titulo),
                  subtitle: Text('${prioridades[c.prioridade]} · SLA até ${c.prazoSla.day.toString().padLeft(2, '0')}/${c.prazoSla.month.toString().padLeft(2, '0')} ${c.prazoSla.hour.toString().padLeft(2, '0')}:${c.prazoSla.minute.toString().padLeft(2, '0')} UTC'),
                ),
            ]);
          },
        ),
      );
}
