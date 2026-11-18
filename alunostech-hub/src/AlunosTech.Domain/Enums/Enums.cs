namespace AlunosTech.Domain.Enums;

public enum PerfilUsuario : byte { Administrador = 1, Gerente = 2, Desenvolvedor = 3, Cliente = 4 }

public enum EstadoTarefa : byte { Backlog = 0, Planejada = 1, EmAndamento = 2, EmRevisao = 3, Concluida = 4 }

public enum PrioridadeChamado : byte { Critica = 1, Alta = 2, Media = 3, Baixa = 4 }
