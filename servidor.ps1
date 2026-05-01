# Servidor HTTP minimo - ejecutar como Administrador
# Lee datos.json y los sirve en http://localhost:7779/data

param([string]$DataDir = "$PSScriptRoot\data")

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:7779/")
$listener.Start()
Write-Host "Servidor OK en http://localhost:7779/data"

while ($listener.IsListening) {
    try {
        $ctx   = $listener.GetContext()
        $resp  = $ctx.Response
        $resp.Headers.Add("Access-Control-Allow-Origin", "*")
        $resp.ContentType = "application/json; charset=utf-8"
        $file  = Join-Path $DataDir "datos.json"
        $json  = if (Test-Path $file) { Get-Content $file -Raw -Encoding UTF8 } else { '{"error":"sin datos"}' }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $resp.ContentLength64 = $bytes.Length
        $resp.OutputStream.Write($bytes, 0, $bytes.Length)
        $resp.OutputStream.Close()
    } catch {}
}
