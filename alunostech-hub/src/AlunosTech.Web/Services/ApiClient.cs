using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace AlunosTech.Web.Services;

public record LoginResult(string AccessToken, string Nome, string Perfil);
public record TarefaVm(int Id, int ProjetoId, int? SprintId, string Titulo, int Estado, int Pontos, string RowVersion);
public record ChamadoVm(int Id, int ClienteId, string Titulo, int Prioridade, DateTime Abertura, DateTime PrazoSla, int Status);
public record ApiResult<T>(HttpStatusCode Status, T? Dados, string? Erro) { public bool Ok => (int)Status is >= 200 and < 300; }

public class ApiClient(HttpClient http, IHttpContextAccessor ctx)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private ISession Sessao => ctx.HttpContext!.Session;

    private void Autenticar()
    {
        var t = Sessao.GetString("token");
        http.DefaultRequestHeaders.Authorization = t is null ? null : new AuthenticationHeaderValue("Bearer", t);
    }

    private static async Task<ApiResult<T>> Ler<T>(HttpResponseMessage r)
    {
        var txt = await r.Content.ReadAsStringAsync();
        if (r.IsSuccessStatusCode)
            return new(r.StatusCode, string.IsNullOrWhiteSpace(txt) ? default : JsonSerializer.Deserialize<T>(txt, Json), null);
        string? erro = null;
        try { erro = JsonDocument.Parse(txt).RootElement.GetProperty("erro").GetString(); } catch { }
        return new(r.StatusCode, default, erro ?? $"Falha HTTP {(int)r.StatusCode}");
    }

    public async Task<ApiResult<LoginResult>> LoginAsync(string email, string senha)
    {
        var r = await http.PostAsJsonAsync("/api/auth/login", new { email, senha });
        return await Ler<LoginResult>(r);
    }

    public async Task<ApiResult<List<TarefaVm>>> TarefasAsync(int projetoId) { Autenticar(); return await Ler<List<TarefaVm>>(await http.GetAsync($"/api/projetos/{projetoId}/tarefas")); }

    public async Task<ApiResult<JsonElement>> MoverAsync(int id, int novoEstado, string rowVersion)
    {
        Autenticar();
        var req = new HttpRequestMessage(HttpMethod.Patch, $"/api/tarefas/{id}/mover") { Content = JsonContent.Create(new { novoEstado, rowVersion }) };
        return await Ler<JsonElement>(await http.SendAsync(req));
    }

    public async Task<ApiResult<List<ChamadoVm>>> ChamadosAsync() { Autenticar(); return await Ler<List<ChamadoVm>>(await http.GetAsync("/api/chamados")); }

    public async Task<ApiResult<JsonElement>> CriarChamadoAsync(int clienteId, string titulo, string? descricao, int prioridade)
    {
        Autenticar();
        return await Ler<JsonElement>(await http.PostAsJsonAsync("/api/chamados", new { clienteId, titulo, descricao, prioridade }));
    }
}
