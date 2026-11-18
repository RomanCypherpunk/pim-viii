using System.Text;
using System.Threading.RateLimiting;
using AlunosTech.Api.Auth;
using AlunosTech.Application.Abstractions;
using AlunosTech.Application.Notifications;
using AlunosTech.Application.Services;
using AlunosTech.Domain.Events;
using AlunosTech.Infrastructure;
using AlunosTech.Infrastructure.Data;
using AlunosTech.Infrastructure.Repositories;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// Configuração por variável de ambiente (12-factor): ConnectionStrings__Default, Jwt__Key ...
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default não configurada.");
var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException("Jwt:Key não configurada.");
if (jwtKey.Length < 32) throw new InvalidOperationException("Jwt:Key deve ter ao menos 32 caracteres.");

builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddInfrastructure(connectionString);

// Casos de uso e padrões (Factory, Observer)
builder.Services.AddScoped<TarefaService>();
builder.Services.AddScoped<ChamadoService>();
builder.Services.AddScoped<SprintService>();
builder.Services.AddScoped<RelatorioService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddSingleton<INotificador, LogNotificador>();
builder.Services.AddSingleton<INotificador, EmailSimuladoNotificador>();
builder.Services.AddSingleton<NotificadorFactory>();
builder.Services.AddSingleton<IDomainEventHandler<TarefaConcluida>, TarefaConcluidaHandler>();
builder.Services.AddSingleton(new TokenService(jwtKey, builder.Configuration["Jwt:Issuer"] ?? "AlunosTech.Api"));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "AlunosTech.Api",
        ValidateIssuer = true,
        ValidateAudience = false,
        ClockSkew = TimeSpan.FromSeconds(5)
    });
builder.Services.AddAuthorization();

// Rate limiting: protege o login contra força bruta
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddFixedWindowLimiter("login", c => { c.PermitLimit = 10; c.Window = TimeSpan.FromMinutes(1); c.QueueLimit = 0; });
});

// CORS restrito por configuração (Cors:Origins). Vazio = nenhuma origem de navegador autorizada.
var origens = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    if (origens.Length > 0) p.WithOrigins(origens).AllowAnyHeader().AllowAnyMethod();
}));

builder.Services.AddHealthChecks()
    .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy(), tags: ["live"])
    .AddCheck<SqlHealthCheck>("sqlserver", tags: ["ready"]);

var app = builder.Build();

// Aplica scripts do banco (DbUp) e dados de desenvolvimento na subida
if (app.Configuration.GetValue("Database:MigrarAoIniciar", true))
{
    var r = DatabaseMigrator.Migrar(connectionString);
    if (!r.Successful) throw new InvalidOperationException("Falha ao migrar o banco.", r.Error);
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<UsuarioRepository>()
        .GarantirUsuariosDeDesenvolvimentoAsync(scope.ServiceProvider.GetRequiredService<IPasswordHasher>(),
            app.Configuration["Seed:SenhaPadrao"] ?? "AlunosTech@2026");
}

app.UseMiddleware<ErrorHandlingMiddleware>();
if (app.Environment.IsDevelopment() || app.Configuration.GetValue("OpenApi:Habilitar", false)) app.MapOpenApi();
app.UseCors();
app.UseRateLimiter();
app.UseHttpMetrics();           // métricas HTTP para o Prometheus
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = c => c.Tags.Contains("live") });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = c => c.Tags.Contains("ready") });
app.MapMetrics();               // /metrics

app.Run();

public partial class Program;
