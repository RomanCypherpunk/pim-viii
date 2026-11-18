-- Demonstracao de otimizacao de consultas: mede ANTES e DEPOIS de criar o indice de cobertura.
-- Executar com: sqlcmd -d AlunosTech -i 01_massa_e_otimizacao.sql   (ou pelo script infra/scripts/run-performance.ps1)
SET NOCOUNT ON;

-- 1) Massa de dados: 50.000 tarefas e 500.000 apontamentos (set-based, sem cursor)
IF (SELECT COUNT(*) FROM dbo.ApontamentoHoras) < 500000
BEGIN
    -- Carga em massa: desabilita o trigger de regra de negocio so durante a carga e limpa cargas parciais
    DISABLE TRIGGER dbo.trg_Apontamento_BloqueiaSprintFechada ON dbo.ApontamentoHoras;
    DELETE FROM dbo.ApontamentoHoras WHERE TarefaId IN (SELECT Id FROM dbo.Tarefa WHERE Titulo LIKE N'Tarefa de carga%');
    DELETE FROM dbo.Tarefa WHERE Titulo LIKE N'Tarefa de carga%';
    DECLARE @ProjetoId INT = (SELECT MIN(Id) FROM dbo.Projeto);
    DECLARE @UserId    INT = (SELECT TOP 1 Id FROM dbo.Usuario);
    IF @UserId IS NULL
    BEGIN
        INSERT INTO dbo.Usuario (Nome, Email, SenhaHash, Perfil) VALUES (N'Perf', N'perf@alunostech.example', N'x', 3);
        SET @UserId = SCOPE_IDENTITY();
    END

    ;WITH n AS (SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects a CROSS JOIN sys.all_objects b)
    INSERT INTO dbo.Tarefa (ProjetoId, Titulo, Estado, Pontos)
    SELECT @ProjetoId, CONCAT(N'Tarefa de carga ', i), i % 5, 1 + i % 8 FROM n;

    DECLARE @MinT INT = (SELECT MIN(Id) FROM dbo.Tarefa WHERE Titulo LIKE N'Tarefa de carga%');
    ;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c)
    INSERT INTO dbo.ApontamentoHoras (TarefaId, UsuarioId, Data, Horas)
    SELECT @MinT + (i % 50000), @UserId, DATEADD(DAY, i % 365, '2026-01-01'), 0.5 + (i % 8) * 0.5 FROM n;
END;
GO
ENABLE TRIGGER dbo.trg_Apontamento_BloqueiaSprintFechada ON dbo.ApontamentoHoras;
DECLARE @nA INT = (SELECT COUNT(*) FROM dbo.ApontamentoHoras), @nT INT = (SELECT COUNT(*) FROM dbo.Tarefa);
PRINT CONCAT('Massa pronta: ', @nA, ' apontamentos, ', @nT, ' tarefas.');
GO

-- 2) ANTES: remove os indices de apoio da tabela de apontamentos
DROP INDEX IF EXISTS IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras;
DROP INDEX IF EXISTS IX_Apont_Data ON dbo.ApontamentoHoras;
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
PRINT '=== ANTES (sem indice) ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
EXEC dbo.sp_RelatorioHorasPorProjeto @De = '2026-03-01', @Ate = '2026-03-31';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO

-- 3) DEPOIS: indice de cobertura filtrando por Data e incluindo as colunas lidas
CREATE INDEX IX_Apont_Data ON dbo.ApontamentoHoras (Data) INCLUDE (TarefaId, Horas, Fechado);
CREATE INDEX IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras (TarefaId, Data) INCLUDE (Horas, Fechado);
DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS;
PRINT '=== DEPOIS (com indice de cobertura) ===';
SET STATISTICS IO ON; SET STATISTICS TIME ON;
EXEC dbo.sp_RelatorioHorasPorProjeto @De = '2026-03-01', @Ate = '2026-03-31';
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO



