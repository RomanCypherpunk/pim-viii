using AlunosTech.Domain.Enums;
using AlunosTech.Domain.Events;
using AlunosTech.Domain.Exceptions;

namespace AlunosTech.Domain.Entities;

/// <summary>Entidade rica: o estado só muda por comportamento que protege as invariantes (encapsulamento).</summary>
public class Tarefa : EntidadeBase
{
    private readonly List<IDomainEvent> _eventos = [];

    public int ProjetoId { get; private set; }
    public int? SprintId { get; private set; }
    public string Titulo { get; private set; } = string.Empty;
    public EstadoTarefa Estado { get; private set; } = EstadoTarefa.Backlog;
    public int Pontos { get; private set; } = 1;
    public byte[] RowVersion { get; private set; } = [];

    public IReadOnlyCollection<IDomainEvent> Eventos => _eventos;

    public Tarefa(int id, int projetoId, string titulo, EstadoTarefa estado, int pontos, byte[]? rowVersion = null, int? sprintId = null)
    {
        if (string.IsNullOrWhiteSpace(titulo)) throw new DomainException("Título é obrigatório.");
        if (pontos is < 1 or > 21) throw new DomainException("Pontos devem estar entre 1 e 21.");
        Id = id; ProjetoId = projetoId; Titulo = titulo; Estado = estado; Pontos = pontos;
        RowVersion = rowVersion ?? []; SprintId = sprintId;
    }

    /// <summary>Regra espelhada na procedure sp_MoverTarefa: só avança ou retrocede um passo.</summary>
    public static bool TransicaoValida(EstadoTarefa de, EstadoTarefa para) => Math.Abs((int)para - (int)de) == 1;

    public void Mover(EstadoTarefa novo)
    {
        if (!TransicaoValida(Estado, novo))
            throw new DomainException($"Transição inválida: {Estado} → {novo}.");
        Estado = novo;
        if (novo == EstadoTarefa.Concluida) _eventos.Add(new TarefaConcluida(Id, ProjetoId, Pontos));
    }

    public void LimparEventos() => _eventos.Clear();
}
