-- Dados de desenvolvimento. Usuarios (com hash BCrypt) sao criados pela API no primeiro start (DevSeeder).
INSERT INTO dbo.Cliente (Nome, Email, Telefone) VALUES
 (N'Mercado Alfa', N'contato@alfa.example', N'11999990001'),
 (N'Clinica Beta', N'ti@beta.example',      N'11999990002');

INSERT INTO dbo.Projeto (ClienteId, Nome, Descricao) VALUES
 (1, N'Portal de Pedidos', N'Portal web de pedidos para o Mercado Alfa'),
 (2, N'App de Agendamentos', N'Aplicativo mobile de agendamento da Clinica Beta');

INSERT INTO dbo.Sprint (ProjetoId, Nome, Inicio, Fim, Meta) VALUES
 (1, N'Sprint 1', '2026-11-02', '2026-11-08', N'Login e catalogo'),
 (1, N'Sprint 2', '2026-11-09', '2026-11-15', N'Carrinho e pedido'),
 (2, N'Sprint 1', '2026-11-02', '2026-11-08', N'Agenda basica');

INSERT INTO dbo.Tarefa (ProjetoId, SprintId, Titulo, Estado, Pontos) VALUES
 (1, 1, N'Tela de login',         4, 3),
 (1, 1, N'Listagem de produtos',  3, 5),
 (1, 1, N'Filtro por categoria',  2, 2),
 (1, 2, N'Carrinho de compras',   1, 5),
 (1, NULL, N'Integracao com pagamento', 0, 8),
 (2, 3, N'Tela de agenda',        2, 5),
 (2, NULL, N'Lembretes por push', 0, 3);
