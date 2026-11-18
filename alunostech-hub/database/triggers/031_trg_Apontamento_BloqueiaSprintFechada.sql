-- Regra de negocio no banco: nao se aponta horas em tarefa de sprint encerrada nem em periodo ja fechado.
CREATE OR ALTER TRIGGER dbo.trg_Apontamento_BloqueiaSprintFechada
ON dbo.ApontamentoHoras
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Tarefa t ON t.Id = i.TarefaId
        JOIN dbo.Sprint s ON s.Id = t.SprintId
        WHERE s.Encerrada = 1)
    BEGIN
        THROW 50040, 'Nao e permitido apontar horas em tarefa de sprint encerrada.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.FechamentoMensal f ON f.Ano = YEAR(i.Data) AND f.Mes = MONTH(i.Data))
    BEGIN
        THROW 50041, 'Periodo mensal ja fechado.', 1;
    END
END;
