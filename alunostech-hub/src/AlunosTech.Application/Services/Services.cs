using AlunosTech.Application.Abstractions;
using AlunosTech.Application.Dtos;
using AlunosTech.Domain.Entities;
using AlunosTech.Domain.Enums;
using AlunosTech.Domain.Events;
using AlunosTech.Domain.Exceptions;
using AlunosTech.Domain.Sla;

namespace AlunosTech.Application.Services;

public sealed class TarefaService(ITarefaRepository repo, IDomainEventHandler<TarefaConcluida> aoConcluir)
{
    public Task<IReadOnlyList<TarefaDto>> ListarAsync(int projetoId, CancellationToken ct = default) =>
        repo.ListarPorProjetoAsync(projetoId, ct);

    public async Task<string> MoverAsync(int id, MoverTarefaRequest req, CancellationToken ct = default)
    {
        var tarefa = await repo.ObterAsync(id, ct) ?? throw new DomainException("Tarefa inexistente.");
        var versaoCliente = Convert.FromBase64String(req.RowVersion);
        // Concorrência otimista: o cliente trabalhou sobre uma versão obsoleta -> 409 (antes de qualquer outra regra).
        // A procedure repete a checagem sob UPDLOCK para cobrir a janela de corrida entre leitura e escrita.
        if (!tarefa.RowVersion.SequenceEqual(versaoCliente))
            throw new ConcurrencyConflictException("Conflito de concorrência: a tarefa foi alterada por outro usuário.");
        tarefa.Mover(req.NovoEstado); // valida a regra de domínio ANTES de ir ao banco
        var rv = await repo.MoverAsync(id, req.NovoEstado, versaoCliente, ct);
        foreach (var e in tarefa.Eventos.OfType<TarefaConcluida>()) await aoConcluir.HandleAsync(e, ct);
        tarefa.LimparEventos();
        return Convert.ToBase64String(rv);
    }
}

public sealed class ChamadoService(IChamadoRepository repo)
{
    public Task<int> CriarAsync(CriarChamadoRequest req, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(req.Titulo)) throw new DomainException("Título é obrigatório.");
        return repo.CriarAsync(req, ct);
    }

    public Task<IReadOnlyList<ChamadoDto>> ListarAsync(int? perfil, int? clienteId, CancellationToken ct = default) =>
        repo.ListarAsync(perfil, clienteId, ct);

    /// <summary>Estimativa do vencimento via Strategy (mesma regra do banco).</summary>
    public static DateTime EstimarVencimento(PrioridadeChamado p, DateTime abertura) =>
        SlaFactory.Para(p).CalcularVencimento(abertura);
}

public sealed class SprintService(ISprintRepository repo)
{
    public Task<int> FecharAsync(int sprintId, CancellationToken ct = default) => repo.FecharAsync(sprintId, ct);
}

public sealed class RelatorioService(IRelatorioRepository repo)
{
    public Task<IReadOnlyList<HorasProjetoDto>> HorasPorProjetoAsync(DateOnly de, DateOnly ate, int pagina = 1, int tamanho = 50, CancellationToken ct = default)
    {
        if (ate < de) throw new DomainException("Período inválido.");
        return repo.HorasPorProjetoAsync(de, ate, Math.Max(1, pagina), Math.Clamp(tamanho, 1, 200), ct);
    }

    public Task<decimal> FecharHorasMesAsync(short ano, byte mes, CancellationToken ct = default) =>
        repo.FecharHorasMesAsync(ano, mes, ct);
}

public sealed class AuthService(IUsuarioRepository repo, IPasswordHasher hasher)
{
    public async Task<Usuario?> AutenticarAsync(LoginRequest req, CancellationToken ct = default)
    {
        var u = await repo.ObterPorEmailAsync(req.Email.Trim().ToLowerInvariant(), ct);
        return u is { Ativo: true } && hasher.Verificar(req.Senha, u.SenhaHash) ? u : null;
    }
}
