-- Row-Level Security: o perfil Cliente (4) so enxerga chamados do proprio cliente.
-- A aplicacao define SESSION_CONTEXT (Perfil, ClienteId) a cada conexao; o banco filtra mesmo que a camada de aplicacao falhe.
CREATE SCHEMA Seguranca;
GO
CREATE OR ALTER FUNCTION Seguranca.fn_FiltroCliente (@ClienteId INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Permitido
    WHERE CAST(SESSION_CONTEXT(N'Perfil') AS INT) IS NULL      -- conexao administrativa/migracao
       OR CAST(SESSION_CONTEXT(N'Perfil') AS INT) <> 4         -- equipe interna enxerga tudo
       OR @ClienteId = CAST(SESSION_CONTEXT(N'ClienteId') AS INT);
GO
CREATE SECURITY POLICY Seguranca.PoliticaChamadoCliente
    ADD FILTER PREDICATE Seguranca.fn_FiltroCliente(ClienteId) ON dbo.Chamado
    WITH (STATE = ON);
