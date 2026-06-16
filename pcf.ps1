<#
  pcf.ps1 — play the classic PC Fútbol games locally on Windows.

  Usage (PowerShell):
    .\pcf.ps1 play pcf5
    .\pcf.ps1 list
    .\pcf.ps1 get pcf5
    .\pcf.ps1 doctor
    .\pcf.ps1 clean

  Requirements: Windows 10+ (ships with curl.exe). Python 3 is recommended for
  the fastest local server; if it is missing a built-in PowerShell server is
  used as a fallback.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string] $Command = "help",
  [Parameter(Position = 1)] [string] $Game = ""
)

$ErrorActionPreference = "Stop"
$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $Root "data"
$PlayDir = Join-Path $Root ".play"
$DisksDir = Join-Path $PlayDir "disks"
$Origin  = if ($env:PCF_ORIGIN_BASE) { $env:PCF_ORIGIN_BASE } else { "https://online.dinamicmultimedia.es" }
$Discos  = if ($env:PCF_DISKS_BASE) { $env:PCF_DISKS_BASE } elseif ($env:PCF_MIRROR) { $env:PCF_MIRROR } else { "https://discos.dinamicmultimedia.es" }
# Optional maintainer-shipped mirror (data/mirror.json) — env vars still win.
$mirrorFile = Join-Path $DataDir "mirror.json"
if (Test-Path $mirrorFile) {
  $m = Get-Content $mirrorFile -Raw | ConvertFrom-Json
  if (-not $env:PCF_ORIGIN_BASE -and $m.origin) { $Origin = $m.origin }
  if (-not $env:PCF_DISKS_BASE -and -not $env:PCF_MIRROR -and $m.disks) { $Discos = $m.disks }
}
# Host literally referenced inside the official games.js (rewritten to ./disks).
$DiscosOfficial = "https://discos.dinamicmultimedia.es"
$OriginOfficial = "https://online.dinamicmultimedia.es"
$Port    = if ($env:PCF_PORT) { [int]$env:PCF_PORT } else { 8782 }
$RateLimit = $env:PCF_RATE_LIMIT
$UserAgent = if ($env:PCF_UA) { $env:PCF_UA } else { "pc-futbol-local (+https://github.com/i10s/pc-futbol-local)" }

$RuntimeFiles = @(
  "index.html", "kiosk.html", "games.js", "libv86.js", "v86.wasm",
  "bios/seabios.bin", "bios/vgabios.bin", "assets/dinamic.png", "assets/fonts/lato.css"
)

function Info($m) { Write-Host "▸ $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

function Get-Games { (Get-Content (Join-Path $DataDir "games.json") -Raw | ConvertFrom-Json).games }
function Find-Game($id) {
  $g = Get-Games | Where-Object { $_.id -eq $id }
  if (-not $g) { Die "Unknown game: $id  (try: .\pcf.ps1 list)" }
  $g
}
function Human([double]$n) {
  foreach ($u in "B", "KiB", "MiB", "GiB", "TiB") {
    if ($n -lt 1024 -or $u -eq "TiB") { return ("{0:N1} {1}" -f $n, $u) }
    $n /= 1024
  }
}
function Get-Python {
  foreach ($c in "python3", "python", "py") {
    $p = Get-Command $c -ErrorAction SilentlyContinue
    if ($p) { return $p.Source }
  }
  return $null
}

function Download-Try($url, $dest, $expected) {
  $dir = Split-Path -Parent $dest
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ($expected -and (Test-Path $dest) -and ((Get-Item $dest).Length -eq $expected)) { return $true }
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) {
    # One connection, identifiable UA, exponential backoff; resume with -C -.
    $cargs = @("--location", "--fail", "--user-agent", $UserAgent,
             "--retry", "5", "--retry-delay", "3", "--retry-connrefused", "--retry-max-time", "120",
             "-C", "-", "-o", $dest)
    if ($RateLimit) { $cargs += @("--limit-rate", $RateLimit) }
    $cargs += $url
    & curl.exe @cargs
    return ($LASTEXITCODE -eq 0)
  } else {
    try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -UserAgent $UserAgent; return $true }
    catch { return $false }
  }
}

# Try the configured source first, then fall back to the official origin so a
# down/blocked mirror never leaves users stuck.
function Download-Mirrored($path, $dest, $expected, $primary, $official) {
  if (Download-Try "$primary/$path" $dest $expected) { return }
  if ($primary -ne $official) {
    Warn "mirror failed for $path — falling back to the official origin"
    if (Download-Try "$official/$path" $dest $expected) { return }
  }
  Die "Download failed: $path"
}
function Download-Small($url, $dest) {
  $dir = Split-Path -Parent $dest
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing } catch { Warn "could not fetch $url" }
}

function Mirror-Runtime {
  if (Test-Path (Join-Path $PlayDir ".runtime-ok")) { return }
  Info "Setting up the local emulator (one-time)…"
  foreach ($d in @($PlayDir, $DisksDir, (Join-Path $PlayDir "bios"), (Join-Path $PlayDir "assets/fonts"), (Join-Path $PlayDir "papi"))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  }
  foreach ($f in $RuntimeFiles) { Download-Small "$Origin/$f" (Join-Path $PlayDir $f) }

  $gjs = Join-Path $PlayDir "games.js"
  if (Test-Path $gjs) {
    (Get-Content $gjs -Raw).Replace("$DiscosOfficial/", "disks/") | Set-Content $gjs -NoNewline
    [regex]::Matches((Get-Content $gjs -Raw), '/assets/[A-Za-z0-9_-]+\.(png|jpg|svg)') |
      ForEach-Object { $_.Value } | Select-Object -Unique | ForEach-Object {
        $local = Join-Path $PlayDir ($_.TrimStart('/'))
        if (-not (Test-Path $local)) { Download-Small "$Origin$_" $local }
      }
  }
  '{"maintenance":false}' | Set-Content (Join-Path $PlayDir "papi/config.json") -NoNewline
  '{}' | Set-Content (Join-Path $PlayDir "papi/names.json") -NoNewline
  New-Item -ItemType File -Force -Path (Join-Path $PlayDir ".runtime-ok") | Out-Null
  Ok "Emulator ready."
}

function Game-Present($g) {
  foreach ($d in $g.disks) { if (-not (Test-Path (Join-Path $DisksDir $d.file))) { return $false } }
  return (Test-Path (Join-Path $PlayDir $g.state))
}

function Download-Game($g) {
  Mirror-Runtime
  $total = ($g.disks | Measure-Object -Property size -Sum).Sum
  Info "Downloading $($g.name) ($($g.year)) — about $(Human $total)"
  Write-Host "  Source: official free servers (Dinamic Multimedia / FX Interactive)." -ForegroundColor DarkGray
  foreach ($d in $g.disks) {
    Info "→ $($d.file)"
    Download-Mirrored $d.file (Join-Path $DisksDir $d.file) $d.size $Discos $DiscosOfficial
  }
  Info "→ $($g.state) (savestate)"
  Download-Mirrored $g.state (Join-Path $PlayDir $g.state) $null $Origin $OriginOfficial
  Ok "$($g.name) is ready to play."
}

# --- Fallback Range-capable static server (used only when Python is absent) ---
function Start-RangeServer($root, $port) {
  $types = @{
    ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8";
    ".css" = "text/css; charset=utf-8"; ".json" = "application/json; charset=utf-8";
    ".wasm" = "application/wasm"; ".png" = "image/png"; ".bin" = "application/octet-stream"
  }
  $listener = [System.Net.HttpListener]::new()
  $listener.Prefixes.Add("http://127.0.0.1:$port/")
  $listener.Start()
  Write-Host "[serve] http://127.0.0.1:$port  root=$root (PowerShell fallback)" -ForegroundColor DarkGray
  try {
    while ($listener.IsListening) {
      $ctx = $listener.GetContext()
      try {
        $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
        if ($rel -eq "") { $rel = "index.html" }
        $full = Join-Path $root ($rel -replace '/', '\')
        if (-not (Test-Path $full -PathType Leaf)) { $ctx.Response.StatusCode = 404; $ctx.Response.Close(); continue }
        $fi = Get-Item $full
        $ctx.Response.Headers["Accept-Ranges"] = "bytes"
        $ext = $fi.Extension.ToLower()
        if ($types.ContainsKey($ext)) { $ctx.Response.ContentType = $types[$ext] } else { $ctx.Response.ContentType = "application/octet-stream" }
        $size = $fi.Length; $start = 0; $end = $size - 1
        $range = $ctx.Request.Headers["Range"]
        if ($range -and $range -match "bytes=(\d*)-(\d*)") {
          if ($Matches[1] -ne "") { $start = [int64]$Matches[1] }
          if ($Matches[2] -ne "") { $end = [int64]$Matches[2] }
          if ($end -ge $size) { $end = $size - 1 }
          $ctx.Response.StatusCode = 206
          $ctx.Response.Headers["Content-Range"] = "bytes $start-$end/$size"
        }
        $len = $end - $start + 1
        $ctx.Response.ContentLength64 = $len
        $fs = [System.IO.File]::OpenRead($full)
        $fs.Seek($start, "Begin") | Out-Null
        $buf = New-Object byte[] (256 * 1024); $remaining = $len
        while ($remaining -gt 0) {
          $toRead = [Math]::Min($buf.Length, $remaining)
          $read = $fs.Read($buf, 0, $toRead)
          if ($read -le 0) { break }
          $ctx.Response.OutputStream.Write($buf, 0, $read)
          $remaining -= $read
        }
        $fs.Close()
      } catch {} finally { try { $ctx.Response.Close() } catch {} }
    }
  } finally { $listener.Stop() }
}

function Find-FreePort([int]$start) {
  for ($p = $start; $p -lt $start + 50; $p++) {
    $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
    try { $l.Start(); $l.Stop(); return $p } catch { continue }
  }
  return $start
}

function Serve-Dir {
  $py = Get-Python
  if ($py) {
    & $py (Join-Path $Root "scripts/serve.py") --root $PlayDir --port $Port --host 127.0.0.1
  } else {
    Warn "Python not found — using the built-in server (install Python 3 for best performance)."
    Start-RangeServer $PlayDir $Port
  }
}

function Play($g) {
  Mirror-Runtime
  if (-not (Game-Present $g)) { Download-Game $g }
  $script:Port = Find-FreePort $Port
  $url = "http://127.0.0.1:$Port/kiosk.html?game=$($g.id)"
  Ok "Now playing: $($g.name)"
  Write-Host "  $url"
  Write-Host "  Press ▶ JUGAR / PLAY in the browser. Saved games persist in this browser." -ForegroundColor DarkGray
  Write-Host "  Close this window (or Ctrl+C) to stop the server." -ForegroundColor DarkGray
  Start-Process $url
  Serve-Dir
}

function Menu {
  Mirror-Runtime
  $script:Port = Find-FreePort $Port
  $url = "http://127.0.0.1:$Port/index.html"
  Ok "Game menu — pick a downloaded title in the browser"
  Write-Host "  $url"
  Write-Host "  Close this window (or Ctrl+C) to stop the server." -ForegroundColor DarkGray
  Start-Process $url
  Serve-Dir
}

function Update {
  Info "Refreshing the local emulator runtime…"
  Remove-Item -Force (Join-Path $PlayDir ".runtime-ok") -ErrorAction SilentlyContinue
  Mirror-Runtime
  Ok "Runtime updated. Your downloaded games are kept."
}

function Show-List {
  Write-Host "Available games:" -ForegroundColor White
  foreach ($g in Get-Games) {
    $mark = "  "
    if (Game-Present $g) { $mark = "● " }
    "{0}{1,-11} {2}  {3}" -f $mark, $g.id, $g.year, $g.name | Write-Host
  }
  Write-Host ""
  Write-Host "● = already downloaded for offline play" -ForegroundColor DarkGray
}

function Doctor {
  Write-Host "Environment check" -ForegroundColor White
  "  OS        : Windows $([Environment]::OSVersion.Version)" | Write-Host
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) { Ok "curl.exe found" } else { Warn "curl.exe missing (Windows 10+ includes it)" }
  $py = Get-Python
  if ($py) { Ok "python found ($py)" } else { Warn "python not found (optional, recommended)" }
  if (Test-Path $PlayDir) { Ok "local data dir: $PlayDir" } else { Info "no data downloaded yet" }
}

function Usage {
  @"
PC Fútbol Local — play the classics in your browser.

Usage
  .\pcf.ps1 play <id>     Download (if needed) and play a game
  .\pcf.ps1 list          List all available games
  .\pcf.ps1 get <id>      Download a game for offline play (no launch)
  .\pcf.ps1 menu          Open the game menu in your browser
  .\pcf.ps1 update        Refresh the local emulator runtime
  .\pcf.ps1 doctor        Check your environment
  .\pcf.ps1 clean         Remove all downloaded data

Examples
  .\pcf.ps1 play pcf5
  .\pcf.ps1 list
"@ | Write-Host
}

switch ($Command.ToLower()) {
  "play"   { if (-not $Game) { Die "usage: .\pcf.ps1 play <id>" }; Play (Find-Game $Game) }
  "get"    { if (-not $Game) { Die "usage: .\pcf.ps1 get <id>" }; Download-Game (Find-Game $Game) }
  "download" { if (-not $Game) { Die "usage: .\pcf.ps1 download <id>" }; Download-Game (Find-Game $Game) }
  "list"   { Show-List }
  "ls"     { Show-List }
  "menu"   { Menu }
  "update" { Update }
  "doctor" { Doctor }
  "clean"  {
    $a = Read-Host "Remove ALL downloaded games and the local emulator ($PlayDir)? [y/N]"
    if ($a -match '^[yY]') { Remove-Item -Recurse -Force $PlayDir; Ok "Removed." } else { Write-Host "Cancelled." }
  }
  default  { Usage }
}
