using AlunosTech.Web.Services;
using Microsoft.AspNetCore.Mvc;

namespace AlunosTech.Web.Controllers;

public class AccountController(ApiClient api) : Controller
{
    [HttpGet] public IActionResult Login() => View();

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(string email, string senha)
    {
        var r = await api.LoginAsync(email, senha);
        if (!r.Ok) { ViewBag.Erro = r.Erro; return View(); }
        HttpContext.Session.SetString("token", r.Dados!.AccessToken);
        HttpContext.Session.SetString("nome", r.Dados.Nome);
        HttpContext.Session.SetString("perfil", r.Dados.Perfil);
        return RedirectToAction("Index", "Kanban");
    }

    public IActionResult Logout() { HttpContext.Session.Clear(); return RedirectToAction(nameof(Login)); }
}

public abstract class AutenticadoController : Controller
{
    public override void OnActionExecuting(Microsoft.AspNetCore.Mvc.Filters.ActionExecutingContext c)
    {
        if (HttpContext.Session.GetString("token") is null) c.Result = RedirectToAction("Login", "Account");
        ViewBag.Nome = HttpContext.Session.GetString("nome");
        ViewBag.Perfil = HttpContext.Session.GetString("perfil");
        base.OnActionExecuting(c);
    }
}

public class KanbanController(ApiClient api) : AutenticadoController
{
    public static readonly string[] Colunas = ["Backlog", "Planejada", "Em andamento", "Em revisão", "Concluída"];

    public async Task<IActionResult> Index(int projetoId = 1)
    {
        var r = await api.TarefasAsync(projetoId);
        ViewBag.ProjetoId = projetoId;
        ViewBag.Erro = TempData["Erro"] ?? r.Erro;
        ViewBag.Ok = TempData["Ok"];
        return View(r.Dados ?? []);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Mover(int id, int novoEstado, string rowVersion, int projetoId)
    {
        var r = await api.MoverAsync(id, novoEstado, rowVersion);
        if (r.Ok) TempData["Ok"] = $"Tarefa {id} movida para '{Colunas[novoEstado]}'.";
        else TempData["Erro"] = r.Status == System.Net.HttpStatusCode.Conflict
            ? "Conflito: outro usuário alterou esta tarefa. A tela foi recarregada com a versão atual."
            : r.Erro;
        return RedirectToAction(nameof(Index), new { projetoId });
    }
}

public class ChamadosController(ApiClient api) : AutenticadoController
{
    public async Task<IActionResult> Index()
    {
        var r = await api.ChamadosAsync();
        ViewBag.Erro = TempData["Erro"] ?? r.Erro; ViewBag.Ok = TempData["Ok"];
        return View(r.Dados ?? []);
    }

    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> Criar(int clienteId, string titulo, string? descricao, int prioridade)
    {
        var r = await api.CriarChamadoAsync(clienteId, titulo, descricao, prioridade);
        if (r.Ok) TempData["Ok"] = "Chamado aberto com sucesso."; else TempData["Erro"] = r.Erro ?? "Não foi possível abrir o chamado.";
        return RedirectToAction(nameof(Index));
    }
}
