namespace AlunosTech.Domain.Events;

public interface IDomainEvent { DateTime OcorridoEm { get; } }

/// <summary>Evento de domínio (padrão Observer): dispara notificações sem acoplar a Tarefa a quem reage.</summary>
public record TarefaConcluida(int TarefaId, int ProjetoId, int Pontos) : IDomainEvent
{
    public DateTime OcorridoEm { get; } = DateTime.UtcNow;
}
