$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $dir 'GearGen3D.html'
$out  = Join-Path $dir 'GearGen3D_offline.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Scarica($url, $minimo, $parola) {
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetFileName($url))
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp
    $txt = [IO.File]::ReadAllText($tmp, $utf8)
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if ($txt.Length -lt $minimo -or $txt.IndexOf($parola) -lt 0) { throw "File scaricato non valido: $url" }
    return $txt.Replace('</script', '<\/script')
}

try {
    Write-Host ''
    Write-Host 'Installazione di GearGen 3D (serve internet solo questa volta)' -ForegroundColor Cyan
    if (-not (Test-Path $src)) { throw 'Non trovo GearGen3D.html: deve stare nella stessa cartella di questo file.' }

    $tagThree = '<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>'
    $tagOrbit = '<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>'
    $html = [IO.File]::ReadAllText($src, $utf8)
    if ($html.IndexOf($tagThree) -lt 0 -or $html.IndexOf($tagOrbit) -lt 0) { throw 'GearGen3D.html non e'' la versione attesa (non trovo i due riferimenti alle librerie).' }

    Write-Host '1/3 Scarico Three.js...'
    $three = Scarica 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js' 100000 'THREE'
    Write-Host '2/3 Scarico i controlli di rotazione...'
    $orbit = Scarica 'https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js' 5000 'OrbitControls'

    $html = $html.Replace($tagThree, "<script>`n" + $three + "`n</script>").Replace($tagOrbit, "<script>`n" + $orbit + "`n</script>")
    if ($html.IndexOf('https://cdn') -ge 0) { throw 'Rimane ancora un riferimento a un sito esterno: operazione annullata.' }
    [IO.File]::WriteAllText($out, $html, $utf8)

    Write-Host '3/3 Creo il collegamento sul Desktop...'
    $pf = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    $cand = foreach ($p in $pf) { "$p\Microsoft\Edge\Application\msedge.exe"; "$p\Google\Chrome\Application\chrome.exe" }
    $browser = $cand | Where-Object { Test-Path $_ } | Select-Object -First 1
    $uri = ([System.Uri]$out).AbsoluteUri
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'GearGen 3D.lnk'))
    if ($browser) { $lnk.TargetPath = $browser; $lnk.Arguments = "--app=$uri"; $lnk.IconLocation = "$browser,0" }
    else { $lnk.TargetPath = $out }
    $lnk.WorkingDirectory = $dir
    $lnk.Save()

    Write-Host ''
    Write-Host 'Fatto! Apri "GearGen 3D" dal Desktop. Ora funziona anche senza internet.' -ForegroundColor Green
    Write-Host 'Non spostare questa cartella, altrimenti il collegamento non la trova piu.'
} catch {
    Write-Host ''
    Write-Host ('ERRORE: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Controlla la connessione internet e riprova.'
    exit 1
}
