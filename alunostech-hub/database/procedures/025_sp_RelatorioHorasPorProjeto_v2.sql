-- v2 (otimizada): agrega primeiro por tarefa (resultado pequeno e ordenado pelo indice) e so depois agrupa por projeto.
-- Remove o COUNT(DISTINCT), que na v1 forcava um Table Spool/Worktable quando o indice de cobertura existia
-- (medido: ~88.900 leituras logicas so no spool). Mesma assinatura e mesmo resultado da v1.
CREATE OR ALTER PROCEDURE dbo.sp_RelatorioHorasPorProjeto
    @De DATE,
    @Ate DATE,
    @Pagina INT = 1,
    @TamanhoPagina INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.Id AS ProjetoId, p.Nome AS Projeto, c.Nome AS Cliente,
           SUM(x.Horas) AS TotalHoras, COUNT(*) AS Tarefas
    FROM (
        SELECT a.TarefaId, SUM(a.Horas) AS Horas
        FROM dbo.ApontamentoHoras a
        WHERE a.Data >= @De AND a.Data <= @Ate
        GROUP BY a.TarefaId
    ) x
    JOIN dbo.Tarefa  t ON t.Id = x.TarefaId
    JOIN dbo.Projeto p ON p.Id = t.ProjetoId
    JOIN dbo.Cliente c ON c.Id = p.ClienteId
    GROUP BY p.Id, p.Nome, c.Nome
    ORDER BY TotalHoras DESC, p.Id
    OFFSET (@Pagina - 1) * @TamanhoPagina ROWS FETCH NEXT @TamanhoPagina ROWS ONLY;
END;
