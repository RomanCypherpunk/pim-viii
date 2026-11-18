using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Windows.Input;

namespace AlunosTech.Desktop;

public record HorasLinha(int ProjetoId, string Projeto, string Cliente, decimal TotalHoras, int Tarefas);

/// <summary>Camada de acesso à API (a mesma consumida pelo web e pelo mobile).</summary>
public sealed class ApiService(string baseUrl)
{
    private readonly HttpClient _http = new() { BaseAddress = new Uri(baseUrl) };
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public async Task<(bool ok, string msg, string? nome)> LoginAsync(string email, string senha)
    {
        var r = await _http.PostAsJsonAsync("/api/auth/login", new { email, senha });
        if (!r.IsSuccessStatusCode) return (false, "Credenciais inválidas.", null);
        var j = JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement;
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", j.GetProperty("accessToken").GetString());
        return (true, "OK", $"{j.GetProperty("nome").GetString()} ({j.GetProperty("perfil").GetString()})");
    }

    public async Task<(List<HorasLinha>? dados, string? erro)> HorasAsync(DateOnly de, DateOnly ate)
    {
        var r = await _http.GetAsync($"/api/relatorios/horas-por-projeto?de={de:yyyy-MM-dd}&ate={ate:yyyy-MM-dd}");
        return r.IsSuccessStatusCode
            ? (await r.Content.ReadFromJsonAsync<List<HorasLinha>>(Json), null)
            : (null, await Erro(r));
    }

    public async Task<(decimal? total, string? erro)> FecharMesAsync(int ano, int mes)
    {
        var r = await _http.PostAsync($"/api/relatorios/fechar-mes/{ano}/{mes}", null);
        if (!r.IsSuccessStatusCode) return (null, await Erro(r));
        return (JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("totalHoras").GetDecimal(), null);
    }

    private static async Task<string> Erro(HttpResponseMessage r)
    {
        try { return JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.GetProperty("erro").GetString() ?? "Erro."; }
        catch { return $"Falha HTTP {(int)r.StatusCode}"; }
    }
}

public abstract class ViewModelBase : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    protected bool Set<T>(ref T campo, T valor, [CallerMemberName] string? nome = null)
    {
        if (EqualityComparer<T>.Default.Equals(campo, valor)) return false;
        campo = valor; PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nome)); return true;
    }
}

/// <summary>Command (padrão MVVM): a View só dispara comandos; a lógica fica no ViewModel.</summary>
public sealed class RelayCommand(Func<Task> executar) : ICommand
{
    public event EventHandler? CanExecuteChanged { add { } remove { } }
    public bool CanExecute(object? parameter) => true;
    public async void Execute(object? parameter) => await executar();
}

public sealed class MainViewModel : ViewModelBase
{
    private readonly ApiService _api;
    private string _email = "", _usuario = "Não autenticado", _status = "Informe suas credenciais.";
    private DateTime? _de = new(2026, 3, 1), _ate = new(2026, 3, 31);
    private int _ano = 2026, _mes = 11;

    public MainViewModel(ApiService api)
    {
        _api = api;
        LoginCommand = new RelayCommand(LoginAsync);
        RelatorioCommand = new RelayCommand(RelatorioAsync);
        FecharMesCommand = new RelayCommand(FecharMesAsync);
        ExportarCommand = new RelayCommand(ExportarAsync);
    }

    public string Email { get => _email; set => Set(ref _email, value); }
    public string Senha { get; set; } = "";
    public string Usuario { get => _usuario; set => Set(ref _usuario, value); }
    public string Status { get => _status; set => Set(ref _status, value); }
    public DateTime? De { get => _de; set => Set(ref _de, value); }
    public DateTime? Ate { get => _ate; set => Set(ref _ate, value); }
    public int Ano { get => _ano; set => Set(ref _ano, value); }
    public int Mes { get => _mes; set => Set(ref _mes, value); }
    public ObservableCollection<HorasLinha> Linhas { get; } = [];

    public ICommand LoginCommand { get; }
    public ICommand RelatorioCommand { get; }
    public ICommand FecharMesCommand { get; }
    public ICommand ExportarCommand { get; }

    public async Task AutoAsync() { await LoginAsync(); await RelatorioAsync(); }

    private async Task LoginAsync()
    {
        var (ok, msg, nome) = await _api.LoginAsync(Email, Senha);
        Usuario = ok ? nome! : "Não autenticado";
        Status = ok ? "Autenticado com sucesso." : msg;
    }

    private async Task RelatorioAsync()
    {
        if (De is null || Ate is null) { Status = "Informe o período."; return; }
        var (dados, erro) = await _api.HorasAsync(DateOnly.FromDateTime(De.Value), DateOnly.FromDateTime(Ate.Value));
        if (dados is null) { Status = erro ?? "Falha ao gerar o relatório."; return; }
        Linhas.Clear(); foreach (var l in dados) Linhas.Add(l);
        Status = $"{dados.Count} projeto(s) no período, {dados.Sum(l => l.TotalHoras):N2} horas no total.";
    }

    private async Task FecharMesAsync()
    {
        var (total, erro) = await _api.FecharMesAsync(Ano, Mes);
        Status = total is null ? $"Fechamento não realizado: {erro}" : $"Mês {Mes:00}/{Ano} fechado com {total:N2} horas.";
    }

    private Task ExportarAsync()
    {
        var caminho = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), $"horas-por-projeto-{DateTime.Now:yyyyMMdd-HHmm}.csv");
        var sb = new StringBuilder("Projeto;Cliente;TotalHoras;Tarefas\n");
        foreach (var l in Linhas) sb.AppendLine($"{l.Projeto};{l.Cliente};{l.TotalHoras:F2};{l.Tarefas}");
        File.WriteAllText(caminho, sb.ToString(), Encoding.UTF8);
        Status = $"CSV exportado em {caminho}";
        return Task.CompletedTask;
    }
}
