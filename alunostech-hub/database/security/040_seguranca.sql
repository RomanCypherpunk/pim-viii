-- Seguranca no banco: menor privilegio, Row-Level Security e mascaramento de dados.

-- 1) Papel da aplicacao: apenas EXECUTE nas procedures e leitura/escrita basica. Nunca db_owner.
IF DATABASE_PRINCIPAL_ID('role_alunostech_app') IS NULL CREATE ROLE role_alunostech_app;
GRANT EXECUTE ON SCHEMA::dbo TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Cliente           TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Usuario           TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Projeto           TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Sprint            TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Tarefa            TO role_alunostech_app;
GRANT SELECT, INSERT         ON dbo.ApontamentoHoras  TO role_alunostech_app;
GRANT SELECT, INSERT, UPDATE ON dbo.Chamado           TO role_alunostech_app;
GRANT SELECT                 ON dbo.AuditoriaTarefa   TO role_alunostech_app;  -- somente leitura: trilha imutavel
GRANT SELECT                 ON dbo.FechamentoMensal  TO role_alunostech_app;

-- 2) Dynamic Data Masking: e-mail mascarado para quem nao tem UNMASK
ALTER TABLE dbo.Usuario ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE dbo.Cliente ALTER COLUMN Telefone ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXXX-",4)');
