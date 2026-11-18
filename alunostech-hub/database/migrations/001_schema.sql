-- 001: esquema relacional do Alunos Tech Hub (SQL Server 2022)
-- Convencoes: PK int identity, ROWVERSION para concorrencia otimista, datas em UTC.

CREATE TABLE dbo.Cliente (
    Id          INT IDENTITY(1,1) CONSTRAINT PK_Cliente PRIMARY KEY,
    Nome        NVARCHAR(120) NOT NULL,
    Email       NVARCHAR(160) NOT NULL,
    Telefone    NVARCHAR(30)  NULL,
    Ativo       BIT NOT NULL CONSTRAINT DF_Cliente_Ativo DEFAULT 1,
    [RowVersion] ROWVERSION NOT NULL
);

CREATE TABLE dbo.Usuario (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Usuario PRIMARY KEY,
    Nome       NVARCHAR(120) NOT NULL,
    Email      NVARCHAR(160) NOT NULL CONSTRAINT UQ_Usuario_Email UNIQUE,
    SenhaHash  NVARCHAR(100) NOT NULL,
    Perfil     TINYINT NOT NULL CONSTRAINT CK_Usuario_Perfil CHECK (Perfil BETWEEN 1 AND 4), -- 1 Admin, 2 Gerente, 3 Dev, 4 Cliente
    ClienteId  INT NULL CONSTRAINT FK_Usuario_Cliente REFERENCES dbo.Cliente(Id),
    Ativo      BIT NOT NULL CONSTRAINT DF_Usuario_Ativo DEFAULT 1
);

CREATE TABLE dbo.Projeto (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Projeto PRIMARY KEY,
    ClienteId  INT NOT NULL CONSTRAINT FK_Projeto_Cliente REFERENCES dbo.Cliente(Id),
    Nome       NVARCHAR(120) NOT NULL,
    Descricao  NVARCHAR(500) NULL,
    CriadoEm   DATETIME2 NOT NULL CONSTRAINT DF_Projeto_Criado DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Sprint (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Sprint PRIMARY KEY,
    ProjetoId  INT NOT NULL CONSTRAINT FK_Sprint_Projeto REFERENCES dbo.Projeto(Id),
    Nome       NVARCHAR(80) NOT NULL,
    Inicio     DATE NOT NULL,
    Fim        DATE NOT NULL,
    Meta       NVARCHAR(300) NULL,
    Encerrada  BIT NOT NULL CONSTRAINT DF_Sprint_Enc DEFAULT 0,
    Velocity   INT NULL,
    CONSTRAINT CK_Sprint_Datas CHECK (Fim >= Inicio)
);

CREATE TABLE dbo.Tarefa (
    Id            INT IDENTITY(1,1) CONSTRAINT PK_Tarefa PRIMARY KEY,
    ProjetoId     INT NOT NULL CONSTRAINT FK_Tarefa_Projeto REFERENCES dbo.Projeto(Id),
    SprintId      INT NULL CONSTRAINT FK_Tarefa_Sprint REFERENCES dbo.Sprint(Id),
    Titulo        NVARCHAR(200) NOT NULL,
    Descricao     NVARCHAR(1000) NULL,
    Estado        TINYINT NOT NULL CONSTRAINT DF_Tarefa_Estado DEFAULT 0
                  CONSTRAINT CK_Tarefa_Estado CHECK (Estado BETWEEN 0 AND 4), -- 0 Backlog,1 Planejada,2 EmAndamento,3 EmRevisao,4 Concluida
    Pontos        INT NOT NULL CONSTRAINT DF_Tarefa_Pontos DEFAULT 1,
    ResponsavelId INT NULL CONSTRAINT FK_Tarefa_Resp REFERENCES dbo.Usuario(Id),
    CriadaEm      DATETIME2 NOT NULL CONSTRAINT DF_Tarefa_Criada DEFAULT SYSUTCDATETIME(),
    [RowVersion]  ROWVERSION NOT NULL
);

CREATE TABLE dbo.ApontamentoHoras (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Apontamento PRIMARY KEY,
    TarefaId   INT NOT NULL CONSTRAINT FK_Apont_Tarefa REFERENCES dbo.Tarefa(Id),
    UsuarioId  INT NOT NULL CONSTRAINT FK_Apont_Usuario REFERENCES dbo.Usuario(Id),
    Data       DATE NOT NULL,
    Horas      DECIMAL(5,2) NOT NULL CONSTRAINT CK_Apont_Horas CHECK (Horas > 0 AND Horas <= 24),
    Fechado    BIT NOT NULL CONSTRAINT DF_Apont_Fechado DEFAULT 0
);

CREATE TABLE dbo.Chamado (
    Id         INT IDENTITY(1,1) CONSTRAINT PK_Chamado PRIMARY KEY,
    ClienteId  INT NOT NULL CONSTRAINT FK_Chamado_Cliente REFERENCES dbo.Cliente(Id),
    Titulo     NVARCHAR(200) NOT NULL,
    Descricao  NVARCHAR(1000) NULL,
    Prioridade TINYINT NOT NULL CONSTRAINT CK_Chamado_Prio CHECK (Prioridade BETWEEN 1 AND 4), -- 1 Critica..4 Baixa
    Abertura   DATETIME2 NOT NULL CONSTRAINT DF_Chamado_Abertura DEFAULT SYSUTCDATETIME(),
    PrazoSla   DATETIME2 NOT NULL,
    Status     TINYINT NOT NULL CONSTRAINT DF_Chamado_Status DEFAULT 0, -- 0 Aberto,1 EmAtendimento,2 Resolvido
    TarefaId   INT NULL CONSTRAINT FK_Chamado_Tarefa REFERENCES dbo.Tarefa(Id)
);

CREATE TABLE dbo.AuditoriaTarefa (
    Id             BIGINT IDENTITY(1,1) CONSTRAINT PK_AuditoriaTarefa PRIMARY KEY,
    TarefaId       INT NOT NULL,
    EstadoAnterior TINYINT NOT NULL,
    EstadoNovo     TINYINT NOT NULL,
    UsuarioBanco   SYSNAME NOT NULL CONSTRAINT DF_Audit_User DEFAULT SUSER_SNAME(),
    Em             DATETIME2 NOT NULL CONSTRAINT DF_Audit_Em DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.FechamentoMensal (
    Id          INT IDENTITY(1,1) CONSTRAINT PK_Fechamento PRIMARY KEY,
    Ano         SMALLINT NOT NULL,
    Mes         TINYINT NOT NULL,
    TotalHoras  DECIMAL(12,2) NOT NULL,
    FechadoEm   DATETIME2 NOT NULL CONSTRAINT DF_Fech_Em DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Fechamento_AnoMes UNIQUE (Ano, Mes)
);
