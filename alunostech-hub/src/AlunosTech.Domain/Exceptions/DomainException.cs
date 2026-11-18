namespace AlunosTech.Domain.Exceptions;

/// <summary>Violação de regra de negócio (mapeada para HTTP 422 na API).</summary>
public class DomainException(string message) : Exception(message);

/// <summary>Conflito de concorrência otimista (mapeado para HTTP 409).</summary>
public class ConcurrencyConflictException(string message) : Exception(message);
