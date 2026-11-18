using AlunosTech.Domain.Enums;

namespace AlunosTech.Application.Dtos;

public record TarefaDto(int Id, int ProjetoId, int? SprintId, string Titulo, EstadoTarefa Estado, int Pontos, string RowVersion);
public record MoverTarefaRequest(EstadoTarefa NovoEstado, string RowVersion);
public record CriarChamadoRequest(int ClienteId, string Titulo, string? Descricao, PrioridadeChamado Prioridade);
public record ChamadoDto(int Id, int ClienteId, string Titulo, PrioridadeChamado Prioridade, DateTime Abertura, DateTime PrazoSla, byte Status);
public record HorasProjetoDto(int ProjetoId, string Projeto, string Cliente, decimal TotalHoras, int Tarefas);
public record LoginRequest(string Email, string Senha);
public record LoginResponse(string AccessToken, string TipoToken, int ExpiraEmSegundos, string Nome, string Perfil);
