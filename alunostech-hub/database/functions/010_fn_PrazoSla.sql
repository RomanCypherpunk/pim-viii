-- Funcao escalar: prazo de SLA conforme a prioridade (1 Critica 4h, 2 Alta 8h, 3 Media 24h, 4 Baixa 72h)
CREATE OR ALTER FUNCTION dbo.fn_PrazoSla (@Prioridade TINYINT, @Abertura DATETIME2)
RETURNS DATETIME2
AS
BEGIN
    RETURN DATEADD(HOUR,
        CASE @Prioridade WHEN 1 THEN 4 WHEN 2 THEN 8 WHEN 3 THEN 24 ELSE 72 END,
        @Abertura);
END;
