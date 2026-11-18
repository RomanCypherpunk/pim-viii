-- Relatorio de horas por projeto no periodo, set-based (sem cursor) e paginado.
CREATE OR ALTER PROCEDURE dbo.sp_RelatorioHorasPorProjeto
    @De DATE,
    @Ate DATE,
    @Pagina INT = 1,
    @TamanhoPagina INT = 50
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
