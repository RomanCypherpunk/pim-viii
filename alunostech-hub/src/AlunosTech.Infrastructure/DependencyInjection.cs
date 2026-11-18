using AlunosTech.Application.Abstractions;
using AlunosTech.Infrastructure.Data;
using AlunosTech.Infrastructure.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace AlunosTech.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, string connectionString)
    {
        services.AddMemoryCache();
        services.AddSingleton<IDbConnectionFactory>(new SqlConnectionFactory(connectionString));
        services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<ITarefaRepository, TarefaRepository>();
        services.AddScoped<IChamadoRepository, ChamadoRepository>();
        services.AddScoped<ISprintRepository, SprintRepository>();
        services.AddScoped<IUsuarioRepository, UsuarioRepository>();
        services.AddScoped<UsuarioRepository>();
        // Decorator: o IRelatorioRepository resolvido já vem com cache
        services.AddScoped<RelatorioRepository>();
        services.AddScoped<IRelatorioRepository>(sp => new RelatorioRepositoryCacheado(
            sp.GetRequiredService<RelatorioRepository>(),
            sp.GetRequiredService<Microsoft.Extensions.Caching.Memory.IMemoryCache>()));
        return services;
    }
}
