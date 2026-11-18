-- Diagnostico: IO de TODAS as tabelas e operadores do plano, com e sem indice.
SET NOCOUNT ON;
GO
DROP INDEX IF EXISTS IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras;
DROP INDEX IF EXISTS IX_Apont_Data ON dbo.ApontamentoHoras;
GO
PRINT '##### SEM INDICES';
SET STATISTICS IO ON;
EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31';
SET STATISTICS IO OFF;
GO
SET SHOWPLAN_TEXT ON;
GO
EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31';
GO
SET SHOWPLAN_TEXT OFF;
GO
CREATE INDEX IX_Apont_Data ON dbo.ApontamentoHoras (Data) INCLUDE (TarefaId, Horas, Fechado);
CREATE INDEX IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras (TarefaId, Data) INCLUDE (Horas, Fechado);
GO
PRINT '##### COM INDICES';
SET STATISTICS IO ON;
EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31';
SET STATISTICS IO OFF;
GO
SET SHOWPLAN_TEXT ON;
GO
EXEC dbo.sp_RelatorioHorasPorProjeto '2026-03-01', '2026-03-31';
GO
SET SHOWPLAN_TEXT OFF;
GO

