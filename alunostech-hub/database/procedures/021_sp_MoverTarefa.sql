-- Move uma tarefa no Kanban com validacao de transicao e controle de concorrencia otimista (ROWVERSION).
-- Codigos de erro: 50001 conflito de concorrencia, 50002 transicao invalida, 50003 tarefa inexistente.
CREATE OR ALTER PROCEDURE dbo.sp_MoverTarefa
    @TarefaId   INT,
    @NovoEstado TINYINT,
    @RowVersion BINARY(8)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Atual TINYINT, @RvAtual BINARY(8);
        SELECT @Atual = Estado, @RvAtual = [RowVersion]
        FROM dbo.Tarefa WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @TarefaId;

        IF @Atual IS NULL THROW 50003, 'Tarefa inexistente.', 1;
        IF @RvAtual <> @RowVersion THROW 50001, 'Conflito de concorrencia: a tarefa foi alterada por outro usuario.', 1;
        -- Fluxo permitido: avancar um passo ou voltar um passo
        IF ABS(CAST(@NovoEstado AS INT) - CAST(@Atual AS INT)) <> 1
            THROW 50002, 'Transicao de estado invalida.', 1;

        UPDATE dbo.Tarefa SET Estado = @NovoEstado WHERE Id = @TarefaId;

        COMMIT TRAN;

        SELECT [RowVersion] FROM dbo.Tarefa WHERE Id = @TarefaId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
