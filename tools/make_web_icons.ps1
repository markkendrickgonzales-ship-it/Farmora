# Regenerates web/favicon.png and web/icons/*.png from assets/images/logo.png.
# Run from the repo root: powershell -File tools\make_web_icons.ps1
Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot '..\assets\images\logo.png'
$webDir = Join-Path $PSScriptRoot '..\web'
$iconDir = Join-Path $webDir 'icons'

$srcImg = [System.Drawing.Image]::FromFile($src)

function Save-Resized([string]$path, [int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $path ($size x $size)"
}

function Save-Maskable([string]$path, [int]$size) {
    # Maskable icons need ~20% safe-zone padding on a solid brand background.
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 47, 93, 80))  # Farmora brand green #2F5D50
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $pad = [int]($size * 0.18)
    $g.DrawImage($srcImg, $pad, $pad, $size - 2 * $pad, $size - 2 * $pad)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $path ($size x $size, maskable)"
}

Save-Resized (Join-Path $webDir 'favicon.png') 32
Save-Resized (Join-Path $iconDir 'Icon-192.png') 192
Save-Resized (Join-Path $iconDir 'Icon-512.png') 512
Save-Maskable (Join-Path $iconDir 'Icon-maskable-192.png') 192
Save-Maskable (Join-Path $iconDir 'Icon-maskable-512.png') 512

$srcImg.Dispose()
Write-Output 'Done.'
