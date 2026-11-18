using AlunosTech.Application.Abstractions;
using AlunosTech.Application.Dtos;
using AlunosTech.Application.Notifications;
using AlunosTech.Application.Services;
using AlunosTech.Domain.Entities;
using AlunosTech.Domain.Enums;
using AlunosTech.Domain.Events;
using AlunosTech.Domain.Exceptions;
using AlunosTech.Domain.Sla;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;

namespace AlunosTech.Domain.Tests;

public class TarefaTests
{
    private static Tarefa Nova(EstadoTarefa e = EstadoTarefa.Backlog) => new(1, 1, "Login", e, 3, [1, 2, 3, 4, 5, 6, 7, 8]);

    [Theory]
    [InlineData(EstadoTarefa.Backlog, EstadoTarefa.Planejada)]
    [InlineData(EstadoTarefa.Planejada, EstadoTarefa.EmAndamento)]
    [InlineData(EstadoTarefa.EmRevisao, EstadoTarefa.EmAndamento)]
    public void Mover_TransicaoValida_AtualizaEstado(EstadoTarefa de, EstadoTarefa para)
    {
        var t = Nova(de);
        t.Mover(para);
        t.Estado.Should().Be(para);
    }

    [Theory]
    [InlineData(EstadoTarefa.Backlog, EstadoTarefa.Concluida)]
    [InlineData(EstadoTarefa.Planejada, EstadoTarefa.EmRevisao)]
    [InlineData(EstadoTarefa.EmAndamento, EstadoTarefa.EmAndamento)]
    public void Mover_TransicaoInvalida_LancaDomainException(EstadoTarefa de, EstadoTarefa para)
    {
        var t = Nova(de);
        var act = () => t.Mover(para);
        act.Should().Throw<DomainException>();
        t.Estado.Should().Be(de, "o estado não pode mudar quando a regra é violada");
    }

    [Fact]
    public void Mover_ParaConcluida_GeraEventoDeDominio()
    {
        var t = Nova(EstadoTarefa.EmRevisao);
        t.Mover(EstadoTarefa.Concluida);
        t.Eventos.Should().ContainSingle().Which.Should().BeOfType<TarefaConcluida>()
            .Which.Pontos.Should().Be(3);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Construtor_TituloVazio_Lanca(string titulo) =>
        ((Action)(() => new Tarefa(1, 1, titulo, EstadoTarefa.Backlog, 1))).Should().Throw<DomainException>();

    [Theory]
    [InlineData(0)]
    [InlineData(22)]
    public void Construtor_PontosForaDaFaixa_Lanca(int pontos) =>
        ((Action)(() => new Tarefa(1, 1, "x", EstadoTarefa.Backlog, pontos))).Should().Throw<DomainException>();
}

public class SlaTests
{
    [Theory]
    [InlineData(PrioridadeChamado.Critica, 4)]
    [InlineData(PrioridadeChamado.Alta, 8)]
    [InlineData(PrioridadeChamado.Media, 24)]
    [InlineData(PrioridadeChamado.Baixa, 72)]
    public void SlaFactory_RetornaEstrategiaCorreta(PrioridadeChamado p, int horas)
    {
        var abertura = new DateTime(2026, 11, 18, 10, 0, 0, DateTimeKind.Utc);
        SlaFactory.Para(p).CalcularVencimento(abertura).Should().Be(abertura.AddHours(horas));
    }
}

public class UsuarioTests
{
    [Fact]
    public void Cliente_SemClienteId_Lanca() =>
        ((Action)(() => new Usuario(1, "Ana", "ana@x.com", "h", PerfilUsuario.Cliente))).Should().Throw<DomainException>();

    [Fact]
    public void Email_EhNormalizado() =>
        new Usuario(1, "Ana", "  ANA@X.COM ", "h", PerfilUsuario.Gerente).Email.Should().Be("ana@x.com");

    [Fact]
    public void Polimorfismo_ObterDescricao() =>
        new Usuario(1, "Ana", "ana@x.com", "h", PerfilUsuario.Gerente).ObterDescricao().Should().Be("Ana (Gerente)");
}

public class NotificadorFactoryTests
{
    [Fact]
    public void Criar_CanalConhecido_RetornaNotificador()
    {
        var f = new NotificadorFactory([new LogNotificador(NullLogger<LogNotificador>.Instance), new EmailSimuladoNotificador(NullLogger<EmailSimuladoNotificador>.Instance)]);
        f.Criar("EMAIL").Canal.Should().Be("email");
    }

    [Fact]
    public void Criar_CanalDesconhecido_Lanca()
    {
        var f = new NotificadorFactory([]);
        ((Action)(() => f.Criar("sms"))).Should().Throw<ArgumentException>();
    }
}

public class TarefaServiceTests
{
    private sealed class RepoFake(Tarefa? tarefa, bool conflito = false) : ITarefaRepository
    {
        public bool ChamouBanco;
        public Task<Tarefa?> ObterAsync(int id, CancellationToken ct = default) => Task.FromResult(tarefa);
        public Task<IReadOnlyList<TarefaDto>> ListarPorProjetoAsync(int p, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<TarefaDto>>([]);
        public Task<byte[]> MoverAsync(int id, EstadoTarefa n, byte[] rv, CancellationToken ct = default)
        {
            ChamouBanco = true;
            return conflito ? throw new ConcurrencyConflictException("conflito") : Task.FromResult<byte[]>([9]);
        }
    }

    private sealed class HandlerFake : IDomainEventHandler<TarefaConcluida>
    {
        public int Chamadas;
        public Task HandleAsync(TarefaConcluida e, CancellationToken ct = default) { Chamadas++; return Task.CompletedTask; }
    }

    private static readonly string Rv = Convert.ToBase64String([1, 2, 3, 4, 5, 6, 7, 8]);

    [Fact]
    public async Task Mover_RowVersionObsoleto_LancaConflito_SemChegarAoBanco()
    {
        var repo = new RepoFake(new Tarefa(1, 1, "x", EstadoTarefa.EmRevisao, 2, [1, 1, 1, 1, 1, 1, 1, 1]));
        var act = () => new TarefaService(repo, new HandlerFake()).MoverAsync(1, new MoverTarefaRequest(EstadoTarefa.Concluida, Rv));
        await act.Should().ThrowAsync<ConcurrencyConflictException>();
        repo.ChamouBanco.Should().BeFalse();
    }

    [Fact]
    public async Task Mover_Concluir_DisparaHandlerDoEvento()
    {
        var repo = new RepoFake(new Tarefa(1, 1, "x", EstadoTarefa.EmRevisao, 2, [1, 2, 3, 4, 5, 6, 7, 8]));
        var handler = new HandlerFake();
        await new TarefaService(repo, handler).MoverAsync(1, new MoverTarefaRequest(EstadoTarefa.Concluida, Rv));
        handler.Chamadas.Should().Be(1);
    }

    [Fact]
    public async Task Mover_TransicaoInvalida_NaoChegaAoBanco()
    {
        var repo = new RepoFake(new Tarefa(1, 1, "x", EstadoTarefa.Backlog, 2, [1, 2, 3, 4, 5, 6, 7, 8]));
        var act = () => new TarefaService(repo, new HandlerFake()).MoverAsync(1, new MoverTarefaRequest(EstadoTarefa.Concluida, Rv));
        await act.Should().ThrowAsync<DomainException>();
        repo.ChamouBanco.Should().BeFalse();
    }

    [Fact]
    public async Task Mover_ConflitoDeConcorrencia_Propaga()
    {
        var repo = new RepoFake(new Tarefa(1, 1, "x", EstadoTarefa.Backlog, 2, [1, 2, 3, 4, 5, 6, 7, 8]), conflito: true);
        var act = () => new TarefaService(repo, new HandlerFake()).MoverAsync(1, new MoverTarefaRequest(EstadoTarefa.Planejada, Rv));
        await act.Should().ThrowAsync<ConcurrencyConflictException>();
    }

    [Fact]
    public async Task Mover_TarefaInexistente_Lanca()
    {
        var act = () => new TarefaService(new RepoFake(null), new HandlerFake()).MoverAsync(7, new MoverTarefaRequest(EstadoTarefa.Planejada, Rv));
        await act.Should().ThrowAsync<DomainException>();
    }
}

public class RelatorioServiceTests
{
    private sealed class RepoFake : IRelatorioRepository
    {
        public int Tamanho;
        public Task<IReadOnlyList<HorasProjetoDto>> HorasPorProjetoAsync(DateOnly de, DateOnly ate, int pagina, int tamanho, CancellationToken ct = default)
        { Tamanho = tamanho; return Task.FromResult<IReadOnlyList<HorasProjetoDto>>([]); }
        public Task<decimal> FecharHorasMesAsync(short ano, byte mes, CancellationToken ct = default) => Task.FromResult(0m);
    }

    [Fact]
    public async Task PeriodoInvalido_Lanca()
    {
        var act = () => new RelatorioService(new RepoFake()).HorasPorProjetoAsync(new DateOnly(2026, 2, 1), new DateOnly(2026, 1, 1));
        await act.Should().ThrowAsync<DomainException>();
    }

    [Fact]
    public async Task TamanhoDePagina_EhLimitado()
    {
        var repo = new RepoFake();
        await new RelatorioService(repo).HorasPorProjetoAsync(new DateOnly(2026, 1, 1), new DateOnly(2026, 1, 31), 1, 5000);
        repo.Tamanho.Should().Be(200);
    }
}

