# Instala o prismon CLI a partir do GitHub Releases (repo público, sem auth).
#
# Uso:
#   irm https://raw.githubusercontent.com/premiersoft/prismon/main/install.ps1 | iex
#   $env:PRISMON_VERSION = '0.1.0'; irm ... | iex
#
# Variáveis:
#   PRISMON_VERSION      versão sem o "v" (default: latest)
#   PRISMON_INSTALL_DIR  default: %LOCALAPPDATA%\prismon
$ErrorActionPreference = 'Stop'

$Repo = 'premiersoft/prismon'
$InstallDir = if ($env:PRISMON_INSTALL_DIR) { $env:PRISMON_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'prismon' }

function Write-Log([string]$Message) {
    [Console]::Error.WriteLine("prismon-install: $Message")
}

function Fail([string]$Message) {
    [Console]::Error.WriteLine("prismon-install: erro: $Message")
    exit 1
}

function Get-Platform {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch) { $arch = $arch.ToLowerInvariant() }
    switch ($arch) {
        'amd64' { return 'windows_amd64' }
        'x64' { return 'windows_amd64' }
        default { Fail "arquitetura $arch não suportada (Path A publica windows/amd64)" }
    }
}

function Get-Version {
    if ($env:PRISMON_VERSION) {
        return $env:PRISMON_VERSION.TrimStart('v')
    }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'prismon-install' }
    if (-not $release.tag_name) {
        Fail "não foi possível resolver a versão (nenhum release em https://github.com/$Repo/releases)"
    }
    return ([string]$release.tag_name).TrimStart('v')
}

function Add-UserPath([string]$Directory) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $parts = @($userPath -split ';' | Where-Object { $_ -ne '' })
    if ($parts -contains $Directory) {
        return
    }
    $newPath = if ($userPath -eq '') { $Directory } else { $userPath.TrimEnd(';') + ';' + $Directory }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Log "aviso: $Directory adicionado ao PATH do usuário — abra um terminal novo"
}

$platform = Get-Platform
$version = Get-Version
Write-Log "versão $version, plataforma $platform"

$bundle = "prismon_${version}_${platform}.zip"
$url = "https://github.com/$Repo/releases/download/v$version/$bundle"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("prismon-install-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $zipPath = Join-Path $tmp $bundle
    Write-Log "baixando $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

    $sumsUrl = "https://github.com/$Repo/releases/download/v$version/prismon_${version}_checksums.txt"
    try {
        $sumsPath = Join-Path $tmp 'checksums.txt'
        Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsPath -UseBasicParsing
        $expected = (Select-String -Path $sumsPath -Pattern "  $([regex]::Escape($bundle))$").Line
        if ($expected) {
            $want = ($expected -split '\s+')[0]
            $got = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLowerInvariant()
            if ($want.ToLowerInvariant() -ne $got) {
                Fail "checksum não confere (esperado $want, obtido $got)"
            }
            Write-Log "checksum ok"
        }
    } catch {
        Write-Log "aviso: não foi possível validar o checksum ($($_.Exception.Message))"
    }

    Expand-Archive -LiteralPath $zipPath -DestinationPath $tmp -Force
    $extracted = Get-ChildItem -Path $tmp -Recurse -Filter 'prismon.exe' | Select-Object -First 1
    if (-not $extracted) {
        Fail "pacote não contém o binário prismon.exe"
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $dest = Join-Path $InstallDir 'prismon.exe'
    $staged = Join-Path $InstallDir '.prismon.install.tmp'
    Copy-Item -LiteralPath $extracted.FullName -Destination $staged -Force
    Unblock-File -LiteralPath $staged -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $dest) {
        $old = "$dest.old"
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
        try {
            Rename-Item -LiteralPath $dest -NewName (Split-Path $old -Leaf)
        } catch {
            Remove-Item -LiteralPath $dest -Force
        }
    }
    Move-Item -LiteralPath $staged -Destination $dest -Force
    Remove-Item -LiteralPath "$dest.old" -Force -ErrorAction SilentlyContinue

    Add-UserPath $InstallDir
    Write-Log "instalado em $dest"
    Write-Log "rode: prismon"
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
