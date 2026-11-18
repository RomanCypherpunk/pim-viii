using AlunosTech.Application.Abstractions;
using AlunosTech.Domain.Events;
using Microsoft.Extensions.Logging;

namespace AlunosTech.Application.Notifications;

public sealed class LogNotificador(ILogger<LogNotificador> log) : INotificador
{
    public string Canal => "log";
    public Task EnviarAsync(string destino, string mensagem, CancellationToken ct = default)
    {
        log.LogInformation("[notificacao:{Canal}] {Destino}: {Mensagem}", Canal, destino, mensagem);
        return Task.CompletedTask;
    }
}

public sealed class EmailSimuladoNotificador(ILogger<EmailSimuladoNotificador> log) : INotificador
{
    public string Canal => "email";
    public Task EnviarAsync(string destino, string mensagem, CancellationToken ct = default)
    {
        log.LogInformation("[email simulado] para {Destino}: {Mensagem}", destino, mensagem);
        return Task.CompletedTask;
    }
}

/// <summary>Factory: resolve o notificador pelo canal, sem if/else no chamador.</summary>
public sealed class NotificadorFactory(IEnumerable<INotificador> notificadores)
{
    private readonly Dictionary<string, INotificador> _mapa =
        notificadores.ToDictionary(n => n.Canal, StringComparer.OrdinalIgnoreCase);

    public INotificador Criar(string canal) =>
        _mapa.TryGetValue(canal, out var n) ? n : throw new ArgumentException($"Canal desconhecido: {canal}");
}

public sealed class TarefaConcluidaHandler(NotificadorFactory fabrica) : IDomainEventHandler<TarefaConcluida>
{
    public Task HandleAsync(TarefaConcluida e, CancellationToken ct = default) =>
        fabrica.Criar("log").EnviarAsync($"projeto-{e.ProjetoId}", $"Tarefa {e.TarefaId} concluída (+{e.Pontos} pontos).", ct);
}
