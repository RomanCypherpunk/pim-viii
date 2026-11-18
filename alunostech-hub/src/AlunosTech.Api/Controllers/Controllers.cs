using System.Security.Claims;
using AlunosTech.Api.Auth;
using AlunosTech.Application.Dtos;
using AlunosTech.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace AlunosTech.Api.Controllers;

[ApiController, Route("api/auth")]
public class AuthController(AuthService auth, TokenService tokens) : ControllerBase
{
    [HttpPost("login"), AllowAnonymous, EnableRateLimiting("login")]
    public async Task<IActionResult> Login(LoginRequest req, CancellationToken ct)
    {
        var u = await auth.AutenticarAsync(req, ct);
        // Mensagem genérica: não revela se o e-mail existe
        return u is null ? Unauthorized(new { erro = "Credenciais inválidas." }) : Ok(tokens.Gerar(u));
    }
}

[ApiController, Route("api/projetos/{projetoId:int}/tarefas"), Authorize]
public class TarefasController(TarefaService tarefas) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Listar(int projetoId, CancellationToken ct) =>
        Ok(await tarefas.ListarAsync(projetoId, ct));
}

[ApiController, Route("api/tarefas"), Authorize(Roles = "Administrador,Gerente,Desenvolvedor")]
public class MoverTarefaController(TarefaService tarefas) : ControllerBase
{
    /// <summary>Move no Kanban. 409 se outro usuário alterou a tarefa (ROWVERSION); 422 se a transição for inválida.</summary>
    [HttpPatch("{id:int}/mover")]
    public async Task<IActionResult> Mover(int id, MoverTarefaRequest req, CancellationToken ct) =>
        Ok(new { rowVersion = await tarefas.MoverAsync(id, req, ct) });
}

[ApiController, Route("api/chamados"), Authorize]
public class ChamadosController(ChamadoService chamados) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Listar(CancellationToken ct) =>
        Ok(await chamados.ListarAsync(Perfil(), ClienteId(), ct));

    [HttpPost]
    public async Task<IActionResult> Criar(CriarChamadoRequest req, CancellationToken ct)
    {
        // Cliente só abre chamado para si mesmo (defesa em profundidade além da RLS)
        if (Perfil() == 4 && ClienteId() != req.ClienteId) return Forbid();
        var id = await chamados.CriarAsync(req, ct);
        return Created($"/api/chamados/{id}", new { id });
    }

    private int? Perfil() => int.TryParse(User.FindFirstValue("perfil"), out var p) ? p : null;
    private int? ClienteId() => int.TryParse(User.FindFirstValue("clienteId"), out var c) ? c : null;
}

[ApiController, Route("api/sprints"), Authorize(Roles = "Administrador,Gerente")]
public class SprintsController(SprintService sprints) : ControllerBase
{
    [HttpPost("{id:int}/fechar")]
    public async Task<IActionResult> Fechar(int id, CancellationToken ct) =>
        Ok(new { velocity = await sprints.FecharAsync(id, ct) });
}

[ApiController, Route("api/relatorios"), Authorize(Roles = "Administrador,Gerente")]
public class RelatoriosController(RelatorioService relatorios) : ControllerBase
{
    [HttpGet("horas-por-projeto")]
    public async Task<IActionResult> Horas([FromQuery] DateOnly de, [FromQuery] DateOnly ate,
        [FromQuery] int pagina = 1, [FromQuery] int tamanho = 50, CancellationToken ct = default) =>
        Ok(await relatorios.HorasPorProjetoAsync(de, ate, pagina, tamanho, ct));

    [HttpPost("fechar-mes/{ano:int}/{mes:int}"), Authorize(Roles = "Administrador")]
    public async Task<IActionResult> FecharMes(short ano, byte mes, CancellationToken ct) =>
        Ok(new { totalHoras = await relatorios.FecharHorasMesAsync(ano, mes, ct) });
}
