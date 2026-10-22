# Genera los iconos PWA de CTRL+R a partir de info/Logo.png (236x140, fondo casi blanco).
# - icons/logo.png: logo con fondo transparente (se embebe en index.html)
# - icons/icon-192.png, icon-512.png: logo centrado sobre cuadrado blanco (sin deformar)
# - icons/icon-maskable-512.png: logo dentro de la zona segura (circulo del 80%)
# - icons/apple-touch-icon-180.png
# - Embebe icons/logo.png en index.html (se puede volver a ejecutar si cambia el logo)
# Uso: powershell -ExecutionPolicy Bypass -File tools/generate-icons.ps1

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'info\Logo.png'
$outDir = Join-Path $root 'icons'
New-Item -ItemType Directory -Force $outDir | Out-Null

# 1) Quitar el fondo: relleno por inundacion desde los bordes sobre pixeles claros y poco saturados.
$orig = New-Object System.Drawing.Bitmap($src)
$w = $orig.Width; $h = $orig.Height
$logo = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($logo)
$g.DrawImage($orig, 0, 0, $w, $h)
$g.Dispose(); $orig.Dispose()

$light = 225   # minimo canal para considerarse fondo
$clear = 238   # desde aqui el pixel es totalmente transparente
$visited = New-Object 'bool[]' ($w * $h)
$queue = New-Object 'System.Collections.Generic.Queue[int]'
for ($x = 0; $x -lt $w; $x++) { $queue.Enqueue($x); $queue.Enqueue(($h - 1) * $w + $x) }
for ($y = 0; $y -lt $h; $y++) { $queue.Enqueue($y * $w); $queue.Enqueue($y * $w + $w - 1) }
while ($queue.Count -gt 0) {
    $i = $queue.Dequeue()
    if ($visited[$i]) { continue }
    $visited[$i] = $true
    $px = $i % $w; $py = [math]::Floor($i / $w)
    $c = $logo.GetPixel($px, $py)
    $mn = [math]::Min($c.R, [math]::Min($c.G, $c.B))
    $mx = [math]::Max($c.R, [math]::Max($c.G, $c.B))
    if ($mn -lt $light -or ($mx - $mn) -gt 24) { continue }
    if ($mn -ge $clear) { $a = 0 } else { $a = [int](255 * ($clear - $mn) / ($clear - $light)) }
    $logo.SetPixel($px, $py, [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B))
    if ($px -gt 0) { $queue.Enqueue($i - 1) }
    if ($px -lt $w - 1) { $queue.Enqueue($i + 1) }
    if ($py -gt 0) { $queue.Enqueue($i - $w) }
    if ($py -lt $h - 1) { $queue.Enqueue($i + $w) }
}
$logo.Save((Join-Path $outDir 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# 2) Iconos cuadrados: el logo conserva su proporcion y se centra con relleno.
function New-Icon([int]$size, [double]$logoWidthRatio, [string]$name) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gfx.Clear([System.Drawing.Color]::White)
    $lw = [int]($size * $logoWidthRatio)
    $lh = [int]($lw * $h / $w)
    $gfx.DrawImage($logo, [int](($size - $lw) / 2), [int](($size - $lh) / 2), $lw, $lh)
    $bmp.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose(); $bmp.Dispose()
}

New-Icon 192 0.90 'icon-192.png'
New-Icon 512 0.90 'icon-512.png'
# Zona segura maskable: el rectangulo del logo debe caber en un circulo de diametro 0.8*size.
$diag = [math]::Sqrt(1 + [math]::Pow($h / $w, 2))
New-Icon 512 (0.78 / $diag) 'icon-maskable-512.png'
New-Icon 180 0.86 'apple-touch-icon-180.png'

$logo.Dispose()
Get-ChildItem $outDir | ForEach-Object { Write-Host ("{0,-28} {1,8} bytes" -f $_.Name, $_.Length) }

# 3) Embeber el logo en index.html: reemplaza el data URI marcado con /*logo*/.
$html = Join-Path $root 'index.html'
if (Test-Path $html) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $texto = [IO.File]::ReadAllText($html, $utf8)
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $outDir 'logo.png')))
    $patron = 'url\("data:image/png;base64,[^"]*"\)/\*logo\*/'
    if ($texto -match $patron) {
        $texto = [regex]::Replace($texto, $patron, 'url("data:image/png;base64,' + $b64 + '")/*logo*/')
        [IO.File]::WriteAllText($html, $texto, $utf8)
        Write-Host "Logo embebido en index.html ($($b64.Length) caracteres)"
    } else {
        Write-Host 'No se encontro el marcador /*logo*/ en index.html'
    }
}
