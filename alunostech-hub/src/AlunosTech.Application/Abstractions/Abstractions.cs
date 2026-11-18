using AlunosTech.Application.Dtos;
using AlunosTech.Domain.Entities;
using AlunosTech.Domain.Enums;
using AlunosTech.Domain.Events;

namespace AlunosTech.Application.Abstractions;

// Repository: isola a persistência (SQL Server) da lógica de negócio e permite dublês nos testes.
public interface ITarefaRepository
{
    Task<Tarefa?> ObterAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<TarefaDto>> ListarPorProjetoAsync(int projetoId, CancellationToken ct = default);
    /// <summary>Executa dbo.sp_MoverTarefa (transação + ROWVERSION). Retorna o novo RowVersion.</summary>
    Task<byte[]> MoverAsync(int tarefaId, EstadoTarefa novo, byte[] rowVersion, CancellationToken ct = default);
}

public interface IChamadoRepository
{
    Task<int> CriarAsync(CriarChamadoRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<ChamadoDto>> ListarAsync(int? perfil, int? clienteId, CancellationToken ct = default);
}

public interface ISprintRepository
{
    Task<int> FecharAsync(int sprintId, CancellationToken ct = default);
}

public interface IRelatorioRepository
{
    Task<IReadOnlyList<HorasProjetoDto>> HorasPorProjetoAsync(DateOnly de, DateOnly ate, int pagina, int tamanho, CancellationToken ct = default);
    Task<decimal> FecharHorasMesAsync(short ano, byte mes, CancellationToken ct = default);
}

public interface IUsuarioRepository
{
    Task<Usuario?> ObterPorEmailAsync(string email, CancellationToken ct = default);
}

public interface IPasswordHasher
{
    string Hash(string senha);
    bool Verificar(string senha, string hash);
}

// Observer: manipuladores reagem a eventos de domínio sem acoplamento com a entidade.
public interface IDomainEventHandler<in TEvent> where TEvent : IDomainEvent
{
    Task HandleAsync(TEvent evento, CancellationToken ct = default);
}

public interface INotificador
{
    string Canal { get; }
    Task EnviarAsync(string destino, string mensagem, CancellationToken ct = default);
}

public sealed class BcryptPasswordHasher : IPasswordHasher
{
    public string Hash(string senha) => BCrypt.Net.BCrypt.HashPassword(senha, workFactor: 11);
    public bool Verificar(string senha, string hash) => BCrypt.Net.BCrypt.Verify(senha, hash);
}
