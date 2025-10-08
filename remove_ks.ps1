# 🔵 Removendo Kaspersky
Write-Host "🔵 Removendo Kaspersky..." -ForegroundColor Cyan
$ErrorActionPreference = 'Stop'
$LogDir = 'C:\Temp'
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$KES_GUID = '{C9EF800D-54AA-4F60-AB96-5A3966550F53}'
$AGT_GUID = '{0F05E4E5-5A89-482C-9A62-47CC58643788}'
$KES_USER = 'KLAdmin'
$KES_PASS = '!1nf0IS2023@'
function Hex-UTF16LE([string]$s) {
    ([Text.Encoding]::Unicode.GetBytes($s) | ForEach-Object { '{0:X2}' -f $_ }) -join ''
}
$AGT_PWDS = @('!Inter#2025iT$','!1nf0IS2023#')
function Invoke-Msi([string[]]$ArgumentList) {
    (Start-Process msiexec.exe -ArgumentList $ArgumentList -Wait -PassThru).ExitCode
}
function Ok($code){ $code -in 0,1641,3010 }
$kesLog  = Join-Path $LogDir 'KES_uninstall.log'
$kesArgs = @('/x',$KES_GUID,"KLLOGIN=$KES_USER","KLPASSWD=$KES_PASS",'REBOOT=ReallySuppress','/qn','/L*v',$kesLog)
$rc = Invoke-Msi $kesArgs
if     (Ok $rc)      { Write-Host "✅ KES removido (code $rc). Log: $kesLog" }
elseif ($rc -eq 1605){ Write-Host "ℹ️ KES não está instalado. Log: $kesLog" }
else                 { Write-Warning "❌ KES falhou (code $rc). Veja: $kesLog" }
$agtLog = Join-Path $LogDir 'Agent_uninstall.log'
$removed = $false
foreach ($pwd in $AGT_PWDS) {
    $hex = Hex-UTF16LE $pwd
    $agtArgs = @('/x',$AGT_GUID,"KLUNINSTPASSWD=$hex",'REBOOT=ReallySuppress','/qn','/L*v',$agtLog)
    $rc = Invoke-Msi $agtArgs
    if (Ok $rc -or $rc -eq 1605) {
        Write-Host "✅ Agente removido (code $rc) com senha '$pwd' (UTF-16LE HEX). Log: $agtLog" -ForegroundColor Green
        $removed = $true
        break
    } else {}
}
if (-not $removed) {
    Write-Warning "❌ Não foi possível remover o Agente. Veja: $agtLog"
}
