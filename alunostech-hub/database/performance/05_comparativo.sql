-- Comparativo 2x2: consulta v1 (COUNT DISTINCT) x v2 (pre-agregada), SEM e COM indice de cobertura.
-- Metrica 1: leituras logicas totais da sessao (todas as tabelas + worktables). Metrica 2: tempo medio de 30 execucoes.
SET NOCOUNT ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_RelatorioHorasPorProjeto_v1
    @De DATE, @Ate DATE, @Pagina INT = 1, @TamanhoPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.Id AS ProjetoId, p.Nome AS Projeto, c.Nome AS Cliente, SUM(a.Horas) AS TotalHoras, COUNT(DISTINCT t.Id) AS Tarefas
    FROM dbo.ApontamentoHoras a
    JOIN dbo.Tarefa  t ON t.Id = a.TarefaId
    JOIN dbo.Projeto p ON p.Id = t.ProjetoId
    JOIN dbo.Cliente c ON c.Id = p.ClienteId
    WHERE a.Data >= @De AND a.Data <= @Ate
    GROUP BY p.Id, p.Nome, c.Nome
    ORDER BY TotalHoras DESC, p.Id
    OFFSET (@Pagina - 1) * @TamanhoPagina ROWS FETCH NEXT @TamanhoPagina ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_BenchComparativo @Proc SYSNAME, @Rotulo NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;
    CREATE TABLE #r (ProjetoId INT, Projeto NVARCHAR(120), Cliente NVARCHAR(120), TotalHoras DECIMAL(18,2), Tarefas INT);
    DECLARE @sql NVARCHAR(400) = N'INSERT INTO #r EXEC dbo.' + QUOTENAME(@Proc) + N' ''2026-03-01'', ''2026-03-31'';';
    DECLARE @i INT = 0, @t0 DATETIME2, @tot BIGINT = 0, @l0 BIGINT, @l1 BIGINT, @leituras BIGINT;
    EXEC sp_executesql @sql;                                    -- aquecimento
    SELECT @l0 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    EXEC sp_executesql @sql;                                    -- 1 execucao medida em leituras
    SELECT @l1 = logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID;
    SET @leituras = @l1 - @l0;
    WHILE @i < 30
    BEGIN
        SET @t0 = SYSDATETIME();
        EXEC sp_executesql @sql;
        SET @tot += DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME());
        SET @i += 1;
    END
    SELECT @Rotulo AS Configuracao, @leituras AS LeiturasLogicasTotais, CAST(@tot / 30 / 1000.0 AS DECIMAL(10,1)) AS TempoMedioMs;
END;
GO
DROP INDEX IF EXISTS IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras;
DROP INDEX IF EXISTS IX_Apont_Data ON dbo.ApontamentoHoras;
GO
EXEC dbo.sp_BenchComparativo 'sp_RelatorioHorasPorProjeto_v1', N'v1 + SEM indice';
EXEC dbo.sp_BenchComparativo 'sp_RelatorioHorasPorProjeto',    N'v2 + SEM indice';
GO
CREATE INDEX IX_Apont_Data ON dbo.ApontamentoHoras (Data) INCLUDE (TarefaId, Horas, Fechado);
CREATE INDEX IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras (TarefaId, Data) INCLUDE (Horas, Fechado);
GO
EXEC dbo.sp_BenchComparativo 'sp_RelatorioHorasPorProjeto_v1', N'v1 + COM indice';
EXEC dbo.sp_BenchComparativo 'sp_RelatorioHorasPorProjeto',    N'v2 + COM indice';
GO
DROP PROCEDURE dbo.sp_BenchComparativo;
DROP PROCEDURE dbo.sp_RelatorioHorasPorProjeto_v1;
GO

