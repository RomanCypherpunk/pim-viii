-- Demonstracoes de banco: funcoes, triggers, transacao/rollback, RLS, mascaramento e privilegio minimo.
SET NOCOUNT ON;
PRINT '=== 1. Objetos programaveis criados ===';
SELECT type_desc AS Tipo, name AS Nome FROM sys.objects
WHERE type IN ('P','FN','IF','TR') AND is_ms_shipped = 0 ORDER BY type_desc, name;

PRINT '';
PRINT '=== 2. Funcao escalar fn_PrazoSla (abertura 2026-11-18 10:00) ===';
SELECT p AS Prioridade, dbo.fn_PrazoSla(p, '2026-11-18T10:00:00') AS PrazoSla FROM (VALUES (1),(2),(3),(4)) v(p);

PRINT '';
PRINT '=== 3. Funcao de tabela fn_TarefasDoSprint(2) ===';
SELECT * FROM dbo.fn_TarefasDoSprint(2);

PRINT '';
PRINT '=== 4. Trigger de auditoria: transicoes registradas pela API ===';
SELECT TOP 10 TarefaId, EstadoAnterior, EstadoNovo, UsuarioBanco, Em FROM dbo.AuditoriaTarefa ORDER BY Id;

PRINT '';
PRINT '=== 5. Trigger de regra: apontar horas em tarefa de sprint ENCERRADA (esperado: erro 50040) ===';
BEGIN TRY
    INSERT INTO dbo.ApontamentoHoras (TarefaId, UsuarioId, Data, Horas) VALUES (1, 3, '2026-11-05', 2);
    PRINT 'INESPERADO: inseriu';
END TRY
BEGIN CATCH
    PRINT CONCAT('Erro ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;

PRINT '';
PRINT '=== 6. Trigger de regra: apontar horas em tarefa valida (backlog, sem sprint) -> permitido ===';
INSERT INTO dbo.ApontamentoHoras (TarefaId, UsuarioId, Data, Horas) VALUES (5, 3, '2026-11-17', 3.5);
SELECT TOP 1 Id, TarefaId, Data, Horas FROM dbo.ApontamentoHoras ORDER BY Id DESC;

PRINT '';
PRINT '=== 7. Periodo mensal fechado (out/2026 fechado pela API) bloqueia novo apontamento (erro 50041) ===';
BEGIN TRY
    INSERT INTO dbo.ApontamentoHoras (TarefaId, UsuarioId, Data, Horas) VALUES (5, 3, '2026-10-15', 1);
    PRINT 'INESPERADO: inseriu';
END TRY
BEGIN CATCH
    PRINT CONCAT('Erro ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;

PRINT '';
PRINT '=== 8. Transacao com ROLLBACK: sp_FecharSprint em sprint inexistente nao deixa efeito colateral ===';
BEGIN TRY
    EXEC dbo.sp_FecharSprint @SprintId = 9999;
END TRY
BEGIN CATCH
    PRINT CONCAT('Erro ', ERROR_NUMBER(), ': ', ERROR_MESSAGE(), ' | transacoes abertas: ', @@TRANCOUNT);
END CATCH;

PRINT '';
PRINT '=== 9. Concorrencia otimista: sp_MoverTarefa com ROWVERSION obsoleto (esperado: erro 50001) ===';
BEGIN TRY
    EXEC dbo.sp_MoverTarefa @TarefaId = 4, @NovoEstado = 2, @RowVersion = 0x0000000000000001;
END TRY
BEGIN CATCH
    PRINT CONCAT('Erro ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;

PRINT '';
PRINT '=== 10. Row-Level Security: mesma tabela, tres contextos ===';
EXEC sp_set_session_context @key = N'Perfil', @value = NULL;
SELECT 'Sem contexto (admin/migracao)' AS Contexto, COUNT(*) AS ChamadosVisiveis FROM dbo.Chamado;
EXEC sp_set_session_context @key = N'Perfil', @value = 4;
EXEC sp_set_session_context @key = N'ClienteId', @value = 1;
SELECT 'Perfil Cliente, ClienteId=1' AS Contexto, COUNT(*) AS ChamadosVisiveis FROM dbo.Chamado;
EXEC sp_set_session_context @key = N'ClienteId', @value = 2;
SELECT 'Perfil Cliente, ClienteId=2' AS Contexto, COUNT(*) AS ChamadosVisiveis FROM dbo.Chamado;
EXEC sp_set_session_context @key = N'Perfil', @value = NULL;

PRINT '';
PRINT '=== 11. Privilegio minimo + Dynamic Data Masking (usuario da aplicacao, sem UNMASK) ===';
IF DATABASE_PRINCIPAL_ID('usr_app_demo') IS NOT NULL DROP USER usr_app_demo;
CREATE USER usr_app_demo WITHOUT LOGIN;
ALTER ROLE role_alunostech_app ADD MEMBER usr_app_demo;
EXECUTE AS USER = 'usr_app_demo';
    SELECT TOP 3 Nome, Email AS EmailVisivelParaApp FROM dbo.Usuario;
    BEGIN TRY
        DELETE FROM dbo.Tarefa WHERE Id = 1;
        PRINT 'INESPERADO: DELETE permitido';
    END TRY
    BEGIN CATCH
        PRINT CONCAT('DELETE em Tarefa negado (erro ', ERROR_NUMBER(), '): ', ERROR_MESSAGE());
    END CATCH;
    BEGIN TRY
        UPDATE dbo.AuditoriaTarefa SET EstadoNovo = 0;
        PRINT 'INESPERADO: UPDATE na auditoria permitido';
    END TRY
    BEGIN CATCH
        PRINT CONCAT('UPDATE na trilha de auditoria negado (erro ', ERROR_NUMBER(), ')');
    END CATCH;
REVERT;
PRINT 'E-mail sem mascara apenas para quem tem UNMASK (sa):';
SELECT TOP 3 Nome, Email FROM dbo.Usuario;
DROP USER usr_app_demo;
