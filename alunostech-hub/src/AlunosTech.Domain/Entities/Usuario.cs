using AlunosTech.Domain.Enums;

namespace AlunosTech.Domain.Entities;

public class Usuario : Pessoa
{
    public string SenhaHash { get; private set; } = string.Empty;
    public PerfilUsuario Perfil { get; private set; }
    public int? ClienteId { get; private set; }
    public bool Ativo { get; private set; } = true;

    protected Usuario() { }

    public Usuario(int id, string nome, string email, string senhaHash, PerfilUsuario perfil, int? clienteId = null)
    {
        Id = id; Nome = nome; Email = email; SenhaHash = senhaHash; Perfil = perfil; ClienteId = clienteId;
        if (perfil == PerfilUsuario.Cliente && clienteId is null)
            throw new Exceptions.DomainException("Usuário do perfil Cliente precisa estar vinculado a um cliente.");
    }

    public override string ObterDescricao() => $"{Nome} ({Perfil})";
}
