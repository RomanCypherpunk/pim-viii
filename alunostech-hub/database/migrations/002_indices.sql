-- 002: indices de apoio (chaves estrangeiras e consultas frequentes)
CREATE INDEX IX_Projeto_Cliente   ON dbo.Projeto (ClienteId);
CREATE INDEX IX_Sprint_Projeto    ON dbo.Sprint (ProjetoId);
CREATE INDEX IX_Tarefa_Sprint     ON dbo.Tarefa (SprintId) INCLUDE (Estado, Pontos);
CREATE INDEX IX_Tarefa_Projeto    ON dbo.Tarefa (ProjetoId, Estado);
CREATE INDEX IX_Chamado_Cliente   ON dbo.Chamado (ClienteId, Status);
-- Indice de cobertura para o relatorio de horas (medido em database/performance)
CREATE INDEX IX_Apont_Tarefa_Data ON dbo.ApontamentoHoras (TarefaId, Data) INCLUDE (Horas, Fechado);
CREATE INDEX IX_Apont_Data        ON dbo.ApontamentoHoras (Data) INCLUDE (TarefaId, Horas, Fechado);
