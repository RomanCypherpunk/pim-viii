using System.Windows;

namespace AlunosTech.Desktop;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm;

    public MainWindow()
    {
        InitializeComponent();
        _vm = new MainViewModel(new ApiService(Environment.GetEnvironmentVariable("ALUNOSTECH_API") ?? "http://localhost:5080"));
        DataContext = _vm;
        Loaded += async (_, _) =>
        {
            // Parâmetros opcionais de linha de comando (automação/testes): --email x --senha y --auto
            var a = Environment.GetCommandLineArgs();
            string? Arg(string n) { var i = Array.IndexOf(a, n); return i >= 0 && i + 1 < a.Length ? a[i + 1] : null; }
            if (Arg("--email") is { } e && Arg("--senha") is { } s)
            {
                _vm.Email = e; SenhaBox.Password = s;
                await _vm.AutoAsync();
            }
        };
    }

    // PasswordBox não suporta binding por segurança; repassa ao ViewModel.
    private void SenhaBox_PasswordChanged(object sender, RoutedEventArgs e) => _vm.Senha = SenhaBox.Password;
}
