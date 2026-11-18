using System.Security.Claims;
using System.Text;
using AlunosTech.Application.Dtos;
using AlunosTech.Domain.Entities;
using AlunosTech.Domain.Exceptions;
using AlunosTech.Infrastructure.Data;
using Dapper;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace AlunosTech.Api.Auth;

public sealed class TokenService(string chave, string emissor)
{
    public const int ExpiracaoSegundos = 8 * 3600;

    public LoginResponse Gerar(Usuario u)
    {
        var claims = new Dictionary<string, object>
        {
            [ClaimTypes.NameIdentifier] = u.Id.ToString(),
            [ClaimTypes.Role] = u.Perfil.ToString(),
            ["perfil"] = (int)u.Perfil,
        };
        if (u.ClienteId is { } cid) claims["clienteId"] = cid;

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = emissor,
            Subject = new ClaimsIdentity([new Claim(JwtRegisteredClaimNames.Email, u.Email), new Claim(JwtRegisteredClaimNames.Name, u.Nome)]),
            Claims = claims,
            Expires = DateTime.UtcNow.AddSeconds(ExpiracaoSegundos),
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(chave)), SecurityAlgorithms.HmacSha256)
        };
        var token = new JsonWebTokenHandler().CreateToken(descriptor);
        return new LoginResponse(token, "Bearer", ExpiracaoSegundos, u.Nome, u.Perfil.ToString());
    }
}

/// <summary>Traduz exceções de domínio em respostas HTTP padronizadas (sem vazar detalhes internos).</summary>
public sealed class ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> log)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        try { await next(ctx); }
        catch (ConcurrencyConflictException ex) { await Responder(ctx, 409, ex.Message); }
        catch (DomainException ex) { await Responder(ctx, 422, ex.Message); }
        catch (Exception ex)
        {
            log.LogError(ex, "Erro não tratado");
            await Responder(ctx, 500, "Erro interno.");
        }
    }

    private static Task Responder(HttpContext ctx, int status, string msg)
    {
        ctx.Response.StatusCode = status;
        return ctx.Response.WriteAsJsonAsync(new { erro = msg });
    }
}

public sealed class SqlHealthCheck(IDbConnectionFactory factory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        try
        {
            await using var c = await factory.AbrirAsync(ct);
            await c.ExecuteScalarAsync<int>("SELECT 1");
            return HealthCheckResult.Healthy();
        }
        catch (Exception ex) { return HealthCheckResult.Unhealthy("SQL Server indisponível", ex); }
    }
}
