-- Encerra a sprint: calcula velocity (pontos concluidos), devolve ao backlog as tarefas nao concluidas
-- e marca a sprint como encerrada. Tudo em uma unica transacao (atomico).
CREATE OR ALTER PROCEDURE dbo.sp_FecharSprint
    @SprintId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM dbo.Sprint WITH (UPDLOCK) WHERE Id = @SprintId)
            THROW 50020, 'Sprint inexistente.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Sprint WHERE Id = @SprintId AND Encerrada = 1)
            THROW 50021, 'Sprint ja encerrada.', 1;

        DECLARE @Velocity INT = ISNULL((SELECT SUM(Pontos) FROM dbo.Tarefa WHERE SprintId = @SprintId AND Estado = 4), 0);

        -- Nao concluidas voltam ao backlog (sem sprint, estado 0)
        UPDATE dbo.Tarefa SET SprintId = NULL, Estado = 0 WHERE SprintId = @SprintId AND Estado <> 4;

        UPDATE dbo.Sprint SET Encerrada = 1, Velocity = @Velocity WHERE Id = @SprintId;

        COMMIT TRAN;
        SELECT @Velocity AS Velocity;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
