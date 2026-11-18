using System.Data;
using AlunosTech.Application.Abstractions;
using AlunosTech.Application.Dtos;
using AlunosTech.Domain.Entities;
using AlunosTech.Domain.Enums;
using AlunosTech.Domain.Exceptions;
using AlunosTech.Infrastructure.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Caching.Memory;

namespace AlunosTech.Infrastructure.Repositories;

/// <summary>Traduz erros T-SQL customizados (50001...) em exceções de domínio.</summary>
internal static class SqlErrors
{
    public static async Task<T> Executar<T>(Func<Task<T>> acao)
    {
        try { return await acao(); }
        catch (SqlException ex) when (ex.Number == 50001) { throw new ConcurrencyConflictException(ex.Message); }
        catch (SqlException ex) when (ex.Number is >= 50002 and < 50100) { throw new DomainException(ex.Message); }
    }
}

public sealed class TarefaRepository(IDbConnectionFactory factory) : ITarefaRepository
{
    private sealed record Linha(int Id, int ProjetoId, int? SprintId, string Titulo, byte Estado, int Pontos, byte[] RowVersion);

    public async Task<Tarefa?> ObterAsync(int id, CancellationToken ct = default)
    {
        await using var c = await factory.AbrirAsync(ct);
        var l = await c.QuerySingleOrDefaultAsync<Linha>(
            "SELECT Id, ProjetoId, SprintId, Titulo, Estado, Pontos, [RowVersion] FROM dbo.Tarefa WHERE Id = @id", new { id });
        return l is null ? null : new Tarefa(l.Id, l.ProjetoId, l.Titulo, (EstadoTarefa)l.Estado, l.Pontos, l.RowVersion, l.SprintId);
    }

    public async Task<IReadOnlyList<TarefaDto>> ListarPorProjetoAsync(int projetoId, CancellationToken ct = default)
    {
        await using var c = await factory.AbrirAsync(ct);
        var linhas = await c.QueryAsync<Linha>(
            "SELECT TOP (200) Id, ProjetoId, SprintId, Titulo, Estado, Pontos, [RowVersion] FROM dbo.Tarefa WHERE ProjetoId = @projetoId ORDER BY Id",
            new { projetoId });
        return linhas.Select(l => new TarefaDto(l.Id, l.ProjetoId, l.SprintId, l.Titulo, (EstadoTarefa)l.Estado, l.Pontos, Convert.ToBase64String(l.RowVersion))).ToList();
    }

    public Task<byte[]> MoverAsync(int tarefaId, EstadoTarefa novo, byte[] rowVersion, CancellationToken ct = default) =>
        SqlErrors.Executar(async () =>
        {
            await using var c = await factory.AbrirAsync(ct);
            return await c.QuerySingleAsync<byte[]>("dbo.sp_MoverTarefa",
                new { TarefaId = tarefaId, NovoEstado = (byte)novo, RowVersion = rowVersion },
                commandType: CommandType.StoredProcedure);
        });
}

public sealed class ChamadoRepository(IDbConnectionFactory factory) : IChamadoRepository
{
    public Task<int> CriarAsync(CriarChamadoRequest r, CancellationToken ct = default) =>
        SqlErrors.Executar(async () =>
        {
            await using var c = await factory.AbrirAsync(ct);
            var p = new DynamicParameters();
            p.Add("ClienteId", r.ClienteId); p.Add("Titulo", r.Titulo); p.Add("Descricao", r.Descricao);
            p.Add("Prioridade", (byte)r.Prioridade);
            p.Add("NovoId", dbType: DbType.Int32, direction: ParameterDirection.Output);
            await c.ExecuteAsync("dbo.sp_CriarChamado", p, commandType: CommandType.StoredProcedure);
            return p.Get<int>("NovoId");
        });

    public async Task<IReadOnlyList<ChamadoDto>> ListarAsync(int? perfil, int? clienteId, CancellationToken ct = default)
    {
        await using var c = await factory.AbrirAsync(ct);
        // Propaga a identidade ao banco: a Row-Level Security filtra por ClienteId quando Perfil = 4 (Cliente).
        await c.ExecuteAsync("EXEC sp_set_session_context @key=N'Perfil', @value=@v", new { v = perfil });
        await c.ExecuteAsync("EXEC sp_set_session_context @key=N'ClienteId', @value=@v", new { v = clienteId });
        var rows = await c.QueryAsync<(int Id, int ClienteId, string Titulo, byte Prioridade, DateTime Abertura, DateTime PrazoSla, byte Status)>(
            "SELECT TOP (200) Id, ClienteId, Titulo, Prioridade, Abertura, PrazoSla, Status FROM dbo.Chamado ORDER BY Abertura DESC");
        return rows.Select(x => new ChamadoDto(x.Id, x.ClienteId, x.Titulo, (PrioridadeChamado)x.Prioridade, x.Abertura, x.PrazoSla, x.Status)).ToList();
    }
}

public sealed class SprintRepository(IDbConnectionFactory factory) : ISprintRepository
{
    public Task<int> FecharAsync(int sprintId, CancellationToken ct = default) =>
        SqlErrors.Executar(async () =>
        {
            await using var c = await factory.AbrirAsync(ct);
            return await c.QuerySingleAsync<int>("dbo.sp_FecharSprint", new { SprintId = sprintId }, commandType: CommandType.StoredProcedure);
        });
}

public sealed class RelatorioRepository(IDbConnectionFactory factory) : IRelatorioRepository
{
    public async Task<IReadOnlyList<HorasProjetoDto>> HorasPorProjetoAsync(DateOnly de, DateOnly ate, int pagina, int tamanho, CancellationToken ct = default)
    {
        await using var c = await factory.AbrirAsync(ct);
        var rows = await c.QueryAsync<HorasProjetoDto>("dbo.sp_RelatorioHorasPorProjeto",
            new { De = de.ToDateTime(TimeOnly.MinValue), Ate = ate.ToDateTime(TimeOnly.MinValue), Pagina = pagina, TamanhoPagina = tamanho },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public Task<decimal> FecharHorasMesAsync(short ano, byte mes, CancellationToken ct = default) =>
        SqlErrors.Executar(async () =>
        {
            await using var c = await factory.AbrirAsync(ct);
            return await c.QuerySingleAsync<decimal>("dbo.sp_FecharHorasMes", new { Ano = ano, Mes = mes }, commandType: CommandType.StoredProcedure);
        });
}

/// <summary>Decorator: adiciona cache em memória ao relatório sem alterar o repositório original.</summary>
public sealed class RelatorioRepositoryCacheado(IRelatorioRepository inner, IMemoryCache cache) : IRelatorioRepository
{
    public Task<IReadOnlyList<HorasProjetoDto>> HorasPorProjetoAsync(DateOnly de, DateOnly ate, int pagina, int tamanho, CancellationToken ct = default) =>
        cache.GetOrCreateAsync($"horas:{de}:{ate}:{pagina}:{tamanho}", e =>
        {
            e.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(60);
            return inner.HorasPorProjetoAsync(de, ate, pagina, tamanho, ct);
        })!;

    public Task<decimal> FecharHorasMesAsync(short ano, byte mes, CancellationToken ct = default) =>
        inner.FecharHorasMesAsync(ano, mes, ct);
}

public sealed class UsuarioRepository(IDbConnectionFactory factory) : IUsuarioRepository
{
    private sealed record Linha(int Id, string Nome, string Email, string SenhaHash, byte Perfil, int? ClienteId);

    public async Task<Usuario?> ObterPorEmailAsync(string email, CancellationToken ct = default)
    {
        await using var c = await factory.AbrirAsync(ct);
        var l = await c.QuerySingleOrDefaultAsync<Linha>(
            "SELECT Id, Nome, Email, SenhaHash, Perfil, ClienteId FROM dbo.Usuario WHERE Email = @email AND Ativo = 1", new { email });
        return l is null ? null : new Usuario(l.Id, l.Nome, l.Email, l.SenhaHash, (PerfilUsuario)l.Perfil, l.ClienteId);
    }

    public async Task GarantirUsuariosDeDesenvolvimentoAsync(IPasswordHasher hasher, string senha)
    {
        await using var c = await factory.AbrirAsync();
        if (await c.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM dbo.Usuario") > 0) return;
        var hash = hasher.Hash(senha);
        await c.ExecuteAsync(
            "INSERT INTO dbo.Usuario (Nome, Email, SenhaHash, Perfil, ClienteId) VALUES " +
            "(N'Administrador', N'admin@alunostech.dev', @hash, 1, NULL), " +
            "(N'Gerente', N'gerente@alunostech.dev', @hash, 2, NULL), " +
            "(N'Dev', N'dev@alunostech.dev', @hash, 3, NULL), " +
            "(N'Cliente Alfa', N'cliente@alfa.example', @hash, 4, 1)", new { hash });
    }
}
