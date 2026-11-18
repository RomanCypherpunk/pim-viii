-- Fechamento mensal de horas: operacao em lote, idempotente (UNIQUE Ano/Mes) e protegida contra
-- concorrencia com isolamento SERIALIZABLE (impede novos apontamentos "fantasma" no periodo durante o fechamento).
CREATE OR ALTER PROCEDURE dbo.sp_FecharHorasMes
    @Ano SMALLINT,
    @Mes TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM dbo.FechamentoMensal WHERE Ano = @Ano AND Mes = @Mes)
            THROW 50030, 'Periodo ja fechado.', 1;

        DECLARE @Ini DATE = DATEFROMPARTS(@Ano, @Mes, 1);
        DECLARE @Fim DATE = DATEADD(MONTH, 1, @Ini);

        DECLARE @Total DECIMAL(12,2) =
            ISNULL((SELECT SUM(Horas) FROM dbo.ApontamentoHoras WHERE Data >= @Ini AND Data < @Fim), 0);

        UPDATE dbo.ApontamentoHoras SET Fechado = 1 WHERE Data >= @Ini AND Data < @Fim;

        INSERT INTO dbo.FechamentoMensal (Ano, Mes, TotalHoras) VALUES (@Ano, @Mes, @Total);

        COMMIT TRAN;
        SELECT @Total AS TotalHoras;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
