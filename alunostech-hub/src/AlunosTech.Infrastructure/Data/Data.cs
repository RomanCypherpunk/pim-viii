using System.Data;
using System.Reflection;
using DbUp;
using DbUp.Engine;
using Microsoft.Data.SqlClient;

namespace AlunosTech.Infrastructure.Data;

public interface IDbConnectionFactory
{
    Task<SqlConnection> AbrirAsync(CancellationToken ct = default);
}

public sealed class SqlConnectionFactory(string connectionString) : IDbConnectionFactory
{
    public async Task<SqlConnection> AbrirAsync(CancellationToken ct = default)
    {
        var c = new SqlConnection(connectionString);
        await c.OpenAsync(ct);
        return c;
    }
}

/// <summary>
/// Aplica os scripts de database/ (embutidos no assembly) em ordem numérica, uma única vez cada (tabela SchemaVersions).
/// Equivalente ao Flyway usado no PIM VI.
/// </summary>
public static class DatabaseMigrator
{
    public static DatabaseUpgradeResult Migrar(string connectionString, Action<string>? log = null)
    {
        EnsureDatabase.For.SqlDatabase(connectionString);

        var assembly = Assembly.GetExecutingAssembly();
        var scripts = assembly.GetManifestResourceNames()
            .Where(n => n.EndsWith(".sql", StringComparison.OrdinalIgnoreCase))
            .Select(n => new { Nome = n, Chave = Path.GetFileName(n.Replace('\\', '/')) })
            .OrderBy(x => x.Chave, StringComparer.Ordinal)
            .Select(x =>
            {
                using var s = assembly.GetManifestResourceStream(x.Nome)!;
                using var r = new StreamReader(s);
                return new SqlScript(x.Chave, r.ReadToEnd());
            })
            .ToList();

        var engine = DeployChanges.To
            .SqlDatabase(connectionString)
            .WithScripts(scripts)
            .WithTransactionPerScript()
            .LogToConsole()
            .Build();

        return engine.PerformUpgrade();
    }
}
