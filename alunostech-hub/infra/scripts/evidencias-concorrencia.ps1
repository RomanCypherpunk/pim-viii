# Demonstra, com DUAS sessoes sqlcmd simultaneas, tres cenarios de concorrencia no SQL Server.
# Uso: powershell -File infra/scripts/evidencias-concorrencia.ps1
param([string]$Senha = 'AlunosTech#2026Strong!')
$tmp = Join-Path $env:TEMP 'alunostech-conc'; New-Item -ItemType Directory -Force $tmp | Out-Null
function Sql($nome, $texto) { $p = Join-Path $tmp $nome; Set-Content $p $texto -Encoding utf8; $p }
function Rodar($arq, $saida) {
    Start-Process sqlcmd -ArgumentList '-S','localhost','-U','sa','-P',$Senha,'-C','-d','AlunosTech','-W','-i',$arq,'-o',$saida -PassThru -WindowStyle Hidden
}
function Exec($q) { sqlcmd -S localhost -U sa -P $Senha -C -d AlunosTech -W -h -1 -Q "SET NOCOUNT ON; $q" }

"=== CENARIO 1: LOST UPDATE (sem controle de concorrencia) ==="
Exec "UPDATE dbo.Tarefa SET Pontos = 5 WHERE Id = 7;" | Out-Null
$a = Sql 'a1.sql' "SET NOCOUNT ON; DECLARE @p INT; SELECT @p = Pontos FROM dbo.Tarefa WHERE Id = 7; PRINT CONCAT('A leu Pontos=', @p); WAITFOR DELAY '00:00:04'; UPDATE dbo.Tarefa SET Pontos = @p + 1 WHERE Id = 7; PRINT 'A gravou Pontos = leitura + 1';"
$b = Sql 'b1.sql' "SET NOCOUNT ON; WAITFOR DELAY '00:00:01'; DECLARE @p INT; SELECT @p = Pontos FROM dbo.Tarefa WHERE Id = 7; PRINT CONCAT('B leu Pontos=', @p); UPDATE dbo.Tarefa SET Pontos = @p + 1 WHERE Id = 7; PRINT 'B gravou Pontos = leitura + 1';"
$pa = Rodar $a "$tmp\a1.out"; $pb = Rodar $b "$tmp\b1.out"; $pa.WaitForExit(); $pb.WaitForExit()
"--- sessao A:"; Get-Content "$tmp\a1.out"; "--- sessao B:"; Get-Content "$tmp\b1.out"
"Valor final de Pontos (esperado 7, duas somas de +1 sobre 5): " + (Exec "SELECT Pontos FROM dbo.Tarefa WHERE Id = 7").Trim()
"=> Uma atualizacao foi PERDIDA (lost update).`n"

"=== CENARIO 2: CONCORRENCIA OTIMISTA com ROWVERSION ==="
Exec "UPDATE dbo.Tarefa SET Pontos = 5 WHERE Id = 7;" | Out-Null
$sqlOtim = @"
SET NOCOUNT ON;
DECLARE @p INT, @rv BINARY(8), @n INT;
SELECT @p = Pontos, @rv = [RowVersion] FROM dbo.Tarefa WHERE Id = 7;
PRINT CONCAT('%S leu Pontos=', @p);
WAITFOR DELAY '00:00:%D';
UPDATE dbo.Tarefa SET Pontos = @p + 1 WHERE Id = 7 AND [RowVersion] = @rv;
SET @n = @@ROWCOUNT;
IF @n = 1 PRINT '%S: atualizacao aceita' ELSE PRINT '%S: CONFLITO detectado (0 linhas) -> a aplicacao devolve HTTP 409 e o usuario recarrega';
"@
$a = Sql 'a2.sql' ($sqlOtim.Replace('%S','A').Replace('%D','04'))
$b = Sql 'b2.sql' ($sqlOtim.Replace('%S','B').Replace('%D','01'))
$pa = Rodar $a "$tmp\a2.out"; $pb = Rodar $b "$tmp\b2.out"; $pa.WaitForExit(); $pb.WaitForExit()
"--- sessao A:"; Get-Content "$tmp\a2.out"; "--- sessao B:"; Get-Content "$tmp\b2.out"
"Valor final de Pontos: " + (Exec "SELECT Pontos FROM dbo.Tarefa WHERE Id = 7").Trim() + " (consistente: so uma atualizacao venceu, a outra foi avisada)`n"

"=== CENARIO 3: DEADLOCK e tratamento com retry ==="
$dl = @"
SET NOCOUNT ON;
DECLARE @tentativa INT = 1;
WHILE @tentativa <= 3
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Tarefa SET Pontos = Pontos WHERE Id = %1;
        WAITFOR DELAY '00:00:03';
        UPDATE dbo.Tarefa SET Pontos = Pontos WHERE Id = %2;
        COMMIT TRAN;
        PRINT CONCAT('%S: concluiu na tentativa ', @tentativa);
        BREAK;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        IF ERROR_NUMBER() = 1205
        BEGIN
            PRINT CONCAT('%S: escolhida como VITIMA do deadlock (erro 1205) na tentativa ', @tentativa, ' -> retry');
            SET @tentativa += 1;
            WAITFOR DELAY '00:00:01';
        END
        ELSE THROW;
    END CATCH
END
"@
$a = Sql 'a3.sql' ($dl.Replace('%S','A').Replace('%1','6').Replace('%2','7'))
$b = Sql 'b3.sql' ($dl.Replace('%S','B').Replace('%1','7').Replace('%2','6'))
$pa = Rodar $a "$tmp\a3.out"; $pb = Rodar $b "$tmp\b3.out"; $pa.WaitForExit(); $pb.WaitForExit()
"--- sessao A:"; Get-Content "$tmp\a3.out"; "--- sessao B:"; Get-Content "$tmp\b3.out"
Exec "UPDATE dbo.Tarefa SET Pontos = 3 WHERE Id = 7;" | Out-Null
