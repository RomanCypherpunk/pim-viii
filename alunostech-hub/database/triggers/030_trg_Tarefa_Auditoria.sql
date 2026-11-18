-- Trilha de auditoria: toda mudanca de estado de tarefa e gravada (usa as pseudo-tabelas inserted/deleted).
CREATE OR ALTER TRIGGER dbo.trg_Tarefa_Auditoria
ON dbo.Tarefa
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditoriaTarefa (TarefaId, EstadoAnterior, EstadoNovo)
    SELECT i.Id, d.Estado, i.Estado
    FROM inserted i
    JOIN deleted d ON d.Id = i.Id
    WHERE i.Estado <> d.Estado;
END;
