# Generates every app/web icon from the new brand images:
#   app_icon.png    -> Android mipmap ic_launcher + iOS AppIcon set (square-padded)
#   logo_app.png    -> web favicon + PWA icons (square-padded)
# Run from repo root:  powershell -ExecutionPolicy Bypass -File tools\make_all_icons.ps1
Add-Type -AssemblyName System.Drawing

$appIcon  = Join-Path $PSScriptRoot '..\assets\images\app_icon.png'
$logoApp  = Join-Path $PSScriptRoot '..\assets\images\logo_app.png'
$resDir   = Join-Path $PSScriptRoot '..\android\app\src\main\res'
$iosDir   = Join-Path $PSScriptRoot '..\ios\Runner\Assets.xcassets\AppIcon.appiconset'
$webDir   = Join-Path $PSScriptRoot '..\web'
$webIcon  = Join-Path $webDir 'icons'

# Draw $src contained (aspect-fit) onto a white $size x $size canvas with an
# optional fractional safe-zone padding, then save as PNG.
function New-SquareIcon([string]$srcPath, [string]$outPath, [int]$size, [double]$padFrac) {
    $src = [System.Drawing.Image]::FromFile($srcPath)
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $pad = [int]($size * $padFrac)
    $inner = $size - 2 * $pad
    $scale = [Math]::Min($inner / $src.Width, $inner / $src.Height)
    $dw = [int]($src.Width * $scale)
    $dh = [int]($src.Height * $scale)
    $x = $pad + [int](($inner - $dw) / 2)
    $y = $pad + [int](($inner - $dh) / 2)
    $g.DrawImage($src, $x, $y, $dw, $dh)
    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $src.Dispose()
    Write-Output "wrote $outPath ($size)"
}

Write-Output '--- Android launcher icons (from app_icon.png) ---'
New-SquareIcon $appIcon (Join-Path $resDir 'mipmap-mdpi\ic_launcher.png')   48   0.06
New-SquareIcon $appIcon (Join-Path $resDir 'mipmap-hdpi\ic_launcher.png')   72   0.06
New-SquareIcon $appIcon (Join-Path $resDir 'mipmap-xhdpi\ic_launcher.png')  96   0.06
New-SquareIcon $appIcon (Join-Path $resDir 'mipmap-xxhdpi\ic_launcher.png') 144  0.06
New-SquareIcon $appIcon (Join-Path $resDir 'mipmap-xxxhdpi\ic_launcher.png') 192 0.06

Write-Output '--- iOS AppIcon set (from app_icon.png) ---'
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-20x20@1x.png')     20   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-20x20@2x.png')     40   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-20x20@3x.png')     60   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-29x29@1x.png')     29   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-29x29@2x.png')     58   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-29x29@3x.png')     87   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-40x40@1x.png')     40   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-40x40@2x.png')     80   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-40x40@3x.png')     120  0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-60x60@2x.png')     120  0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-60x60@3x.png')     180  0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-76x76@1x.png')     76   0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-76x76@2x.png')     152  0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-83.5x83.5@2x.png') 167  0.06
New-SquareIcon $appIcon (Join-Path $iosDir 'Icon-App-1024x1024@1x.png') 1024 0.06

Write-Output '--- Web favicon + PWA icons (from logo_app.png) ---'
New-SquareIcon $logoApp (Join-Path $webDir 'favicon.png')               32   0.0
New-SquareIcon $logoApp (Join-Path $webIcon 'Icon-192.png')             192  0.06
New-SquareIcon $logoApp (Join-Path $webIcon 'Icon-512.png')             512  0.06
New-SquareIcon $logoApp (Join-Path $webIcon 'Icon-maskable-192.png')    192  0.20
New-SquareIcon $logoApp (Join-Path $webIcon 'Icon-maskable-512.png')    512  0.20

Write-Output 'Done.'
