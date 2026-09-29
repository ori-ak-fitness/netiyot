<#
  serve.ps1 - tiny static server for previewing this folder locally.
  (English on purpose: Windows PowerShell 5.1 reads .ps1 files as ANSI,
   so non-ASCII text inside the script would get corrupted.)

  Usage:  powershell -ExecutionPolicy Bypass -File serve.ps1
  Then open:   http://localhost:8090
  Stop:        Ctrl+C
#>

param([int]$Port = 8090)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$prefix = "http://localhost:$Port/"

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.png'  = 'image/png'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
  $listener.Start()
} catch {
  Write-Host "Cannot listen on $prefix - try another port:  .\serve.ps1 -Port 8091" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "  Serving $root at $prefix" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $isHead = ($req.HttpMethod -eq 'HEAD')
      $rel = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
      if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
      $full = Join-Path $root ($rel -replace '/', '\')

      if (Test-Path $full -PathType Container) { $full = Join-Path $full 'index.html' }

      if (Test-Path $full -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $type = $mime[$ext]
        if (-not $type) { $type = 'application/octet-stream' }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $res.ContentType = $type
        $res.StatusCode = 200
        $res.Headers.Add('Cache-Control', 'no-cache, no-store, must-revalidate')
        $res.ContentLength64 = $bytes.Length
        if (-not $isHead) { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
        Write-Host ("  200  /{0}" -f $rel) -ForegroundColor DarkGray
      } else {
        $body = [System.Text.Encoding]::UTF8.GetBytes("404 - Not found: /$rel")
        $res.StatusCode = 404
        $res.ContentType = 'text/plain; charset=utf-8'
        $res.ContentLength64 = $body.Length
        if (-not $isHead) { $res.OutputStream.Write($body, 0, $body.Length) }
        Write-Host ("  404  /{0}" -f $rel) -ForegroundColor Yellow
      }
    } catch {
      Write-Host ("  ERR  {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
    try { $res.OutputStream.Close() } catch { }
  }
} finally {
  $listener.Stop()
  $listener.Close()
  Write-Host "Server stopped." -ForegroundColor DarkGray
}
