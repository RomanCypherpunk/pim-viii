-- Funcao de tabela inline (TVF): tarefas de um sprint. Por ser inline, o otimizador a expande como uma view parametrizada.
CREATE OR ALTER FUNCTION dbo.fn_TarefasDoSprint (@SprintId INT)
RETURNS TABLE
AS
RETURN
(
    SELECT t.Id, t.Titulo, t.Estado, t.Pontos, t.ResponsavelId
    FROM dbo.Tarefa t
    WHERE t.SprintId = @SprintId
);
