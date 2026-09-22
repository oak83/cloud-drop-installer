<#
  pull-run.ps1 — скачать архив из облака в папку на Рабочем столе и запустить скрипт из неё.
  Одна команда:
    powershell -NoProfile -ExecutionPolicy Bypass -File pull-run.ps1
  По умолчанию: приватный репозиторий GitHub. Пароль (token) запрашивается со звёздочками.
#>
param(
    [string]$Repo   = "",                  # GitHub: "логин/репозиторий" (приватный)
    [string]$Ref    = "main",              # ветка/тег/commit
    [string]$Folder = "cloud_drop",        # имя папки на Рабочем столе
    [string]$Run    = "run.cmd",           # какой скрипт запустить из папки
    [string]$ZipUrl = "",                  # произвольный URL архива (вместо GitHub)
    [string]$BaseDir = "",                 # куда класть папку (по умолчанию — Рабочий стол)
    [string]$Token  = ""                   # для автоматизации; пусто = спросить со звёздочками
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- 1. Пароль: Read-Host -AsSecureString показывает звёздочки, в истории не попадает ---
if (-not $Token -and -not $ZipUrl) {
    Write-Host "(пусто = публичный репозиторий, без авторизации)" -ForegroundColor DarkGray
    $ss = Read-Host -Prompt "Token/пароль" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
    try   { $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# --- 2. Папка на Рабочем столе (учитывает перенос Desktop в OneDrive) ---
if (-not $BaseDir) { $BaseDir = [Environment]::GetFolderPath('Desktop') }
$dest = Join-Path $BaseDir $Folder
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# --- 3. Скачивание (curl.exe встроен в Windows 10/11) ---
$tmpZip = Join-Path $env:TEMP 'pull_run_payload.zip'
if ($ZipUrl) {
    $url = $ZipUrl
    $headers = @()
} else {
    if ($Repo -notmatch '/') { throw "Заполни -Repo ('логин/репозиторий') или передай -ZipUrl" }
    $url = "https://api.github.com/repos/$Repo/zipball/$Ref"
    if ($Token) {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$Token"))
        $headers = @('-H', "Authorization: Basic $auth")
    }
}
& curl.exe -sSL --fail @headers -o $tmpZip $url
if ($LASTEXITCODE -ne 0) { throw "Скачивание не удалось (curl code $LASTEXITCODE)" }

# --- 4. Распаковка (zipball GitHub содержит одну корневую папку — выравниваем) ---
$unz = Join-Path $env:TEMP ('pull_run_' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $tmpZip -DestinationPath $unz -Force
$inner = Get-ChildItem $unz -Directory | Select-Object -First 1
if ($inner -and -not (Get-ChildItem $unz -File)) {
    Copy-Item (Join-Path $inner.FullName '*') $dest -Recurse -Force
} else {
    Copy-Item (Join-Path $unz '*') $dest -Recurse -Force
}
Remove-Item $unz, $tmpZip -Recurse -Force

# --- 5. Запуск скрипта из папки ---
$script = Join-Path $dest $Run
if (-not (Test-Path $script)) { throw "Скрипт не найден: $script" }
Write-Host "== Запуск $script ==" -ForegroundColor Green
& cmd.exe /c "`"$script`""
exit $LASTEXITCODE
