-- Cria um chamado calculando o SLA no banco (regra centralizada em fn_PrazoSla).
CREATE OR ALTER PROCEDURE dbo.sp_CriarChamado
    @ClienteId  INT,
    @Titulo     NVARCHAR(200),
    @Descricao  NVARCHAR(1000) = NULL,
    @Prioridade TINYINT,
    @NovoId     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE Id = @ClienteId AND Ativo = 1)
        THROW 50010, 'Cliente inexistente ou inativo.', 1;

    DECLARE @Agora DATETIME2 = SYSUTCDATETIME();

    INSERT INTO dbo.Chamado (ClienteId, Titulo, Descricao, Prioridade, Abertura, PrazoSla)
    VALUES (@ClienteId, @Titulo, @Descricao, @Prioridade, @Agora, dbo.fn_PrazoSla(@Prioridade, @Agora));

    SET @NovoId = SCOPE_IDENTITY();
END;
