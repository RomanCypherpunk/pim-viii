-- Benchmark repetido (30 execucoes por estado) para reduzir ruido de compilacao/cache da medicao unica.
SET NOCOUNT ON;
GO
DROP INDEX IF EXISTS IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras;
DROP INDEX IF EXISTS IX_Apont_Data ON dbo.ApontamentoHoras;
GO
CREATE TABLE #r (ProjetoId INT, Projeto NVARCHAR(120), Cliente NVARCHAR(120), TotalHoras DECIMAL(18,2), Tarefas INT);
DECLARE @i INT = 0, @t0 DATETIME2, @tot BIGINT = 0, @min BIGINT = NULL, @max BIGINT = 0, @d BIGINT;
INSERT INTO #r EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31'; DELETE FROM #r; -- aquecimento (compila o plano)
WHILE @i < 30
BEGIN
    SET @t0 = SYSDATETIME();
    INSERT INTO #r EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31'; DELETE FROM #r;
    SET @d = DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME());
    SET @tot += @d; SET @min = IIF(@min IS NULL OR @d < @min, @d, @min); SET @max = IIF(@d > @max, @d, @max);
    SET @i += 1;
END
PRINT CONCAT('SEM indice  : media ', @tot / 30 / 1000.0, ' ms | min ', @min / 1000.0, ' ms | max ', @max / 1000.0, ' ms (30 execucoes)');
DROP TABLE #r;
GO
CREATE INDEX IX_Apont_Data ON dbo.ApontamentoHoras (Data) INCLUDE (TarefaId, Horas, Fechado);
CREATE INDEX IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras (TarefaId, Data) INCLUDE (Horas, Fechado);
GO
CREATE TABLE #r (ProjetoId INT, Projeto NVARCHAR(120), Cliente NVARCHAR(120), TotalHoras DECIMAL(18,2), Tarefas INT);
DECLARE @i INT = 0, @t0 DATETIME2, @tot BIGINT = 0, @min BIGINT = NULL, @max BIGINT = 0, @d BIGINT;
INSERT INTO #r EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31'; DELETE FROM #r;
WHILE @i < 30
BEGIN
    SET @t0 = SYSDATETIME();
    INSERT INTO #r EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31'; DELETE FROM #r;
    SET @d = DATEDIFF_BIG(MICROSECOND, @t0, SYSDATETIME());
    SET @tot += @d; SET @min = IIF(@min IS NULL OR @d < @min, @d, @min); SET @max = IIF(@d > @max, @d, @max);
    SET @i += 1;
END
PRINT CONCAT('COM indice  : media ', @tot / 30 / 1000.0, ' ms | min ', @min / 1000.0, ' ms | max ', @max / 1000.0, ' ms (30 execucoes)');
GO


