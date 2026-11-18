using AlunosTech.Domain.Enums;

namespace AlunosTech.Domain.Sla;

/// <summary>Strategy: cada prioridade tem sua política de prazo. Espelha dbo.fn_PrazoSla do banco.</summary>
public interface ICalculadoraSla
{
    PrioridadeChamado Prioridade { get; }
    TimeSpan Prazo { get; }
    DateTime CalcularVencimento(DateTime abertura) => abertura.Add(Prazo);
}

public sealed class SlaCritico : ICalculadoraSla { public PrioridadeChamado Prioridade => PrioridadeChamado.Critica; public TimeSpan Prazo => TimeSpan.FromHours(4); }
public sealed class SlaAlto    : ICalculadoraSla { public PrioridadeChamado Prioridade => PrioridadeChamado.Alta;    public TimeSpan Prazo => TimeSpan.FromHours(8); }
public sealed class SlaMedio   : ICalculadoraSla { public PrioridadeChamado Prioridade => PrioridadeChamado.Media;   public TimeSpan Prazo => TimeSpan.FromHours(24); }
public sealed class SlaBaixo   : ICalculadoraSla { public PrioridadeChamado Prioridade => PrioridadeChamado.Baixa;   public TimeSpan Prazo => TimeSpan.FromHours(72); }

/// <summary>Factory: escolhe a estratégia correta, evitando if/else espalhado.</summary>
public static class SlaFactory
{
    private static readonly Dictionary<PrioridadeChamado, ICalculadoraSla> Mapa =
        new ICalculadoraSla[] { new SlaCritico(), new SlaAlto(), new SlaMedio(), new SlaBaixo() }
            .ToDictionary(s => s.Prioridade);

    public static ICalculadoraSla Para(PrioridadeChamado prioridade) => Mapa[prioridade];
}
