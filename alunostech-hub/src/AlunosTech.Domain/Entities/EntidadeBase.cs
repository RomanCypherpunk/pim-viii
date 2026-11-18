namespace AlunosTech.Domain.Entities;

/// <summary>Classe base (herança): identidade comum a todas as entidades.</summary>
public abstract class EntidadeBase
{
    public int Id { get; protected set; }
}

/// <summary>Abstração de pessoa (herança + polimorfismo): cada subtipo descreve a si mesmo.</summary>
public abstract class Pessoa : EntidadeBase
{
    private string _nome = string.Empty;
    private string _email = string.Empty;

    public string Nome
    {
        get => _nome;
        protected set => _nome = string.IsNullOrWhiteSpace(value)
            ? throw new Exceptions.DomainException("Nome é obrigatório.") : value.Trim();
    }

    public string Email
    {
        get => _email;
        protected set => _email = value is not null && value.Contains('@') && value.Contains('.')
            ? value.Trim().ToLowerInvariant() : throw new Exceptions.DomainException("E-mail inválido.");
    }

    public abstract string ObterDescricao();
}
