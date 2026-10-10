# Deterministic Android resource generation; requires Windows/System.Drawing.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'assets/branding/tanda_icon_1024.png'
$resourceRoot = Join-Path $repoRoot 'android/app/src/main/res'
$source = [System.Drawing.Bitmap]::new($sourcePath)
try {
    if ($source.Width -ne 1024 -or $source.Height -ne 1024) {
        throw 'Expected the supplied 1024 x 1024 branding source.'
    }
    $foreground = [System.Drawing.Bitmap]::new(1024, 1024)
    $graphics = [System.Drawing.Graphics]::FromImage($foreground)
    $clip = [System.Drawing.Drawing2D.GraphicsPath]::new()
    try {
        # Keep the original medallion (including its brown outline), without
        # the opaque square corners. Its diameter is 65.25 dp on a 108 dp
        # adaptive canvas, inside Android's central 66 dp safe circle.
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.SmoothingMode = 'AntiAlias'
        $graphics.InterpolationMode = 'HighQualityBicubic'
        $scale = 2.0 / 3.0
        $radius = 464 * $scale
        $clip.AddEllipse([single](512 - $radius), [single](512 - $radius), [single](2 * $radius), [single](2 * $radius))
        $graphics.SetClip($clip)
        $graphics.DrawImage($source, [System.Drawing.RectangleF]::new([single](1024 / 6), [single](1024 / 6), [single](1024 * $scale), [single](1024 * $scale)))
    } finally {
        $clip.Dispose()
        $graphics.Dispose()
    }
    try {
        foreach ($entry in @(@('mdpi', 48, 108), @('hdpi', 72, 162), @('xhdpi', 96, 216), @('xxhdpi', 144, 324), @('xxxhdpi', 192, 432))) {
            $directory = Join-Path $resourceRoot "mipmap-$($entry[0])"
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            foreach ($asset in @(@('ic_launcher.png', $source, $entry[1]), @('ic_launcher_foreground.png', $foreground, $entry[2]))) {
                $size = [int]$asset[2]
                $bitmap = [System.Drawing.Bitmap]::new($size, $size)
                $draw = [System.Drawing.Graphics]::FromImage($bitmap)
                try {
                    $draw.Clear([System.Drawing.Color]::Transparent)
                    $draw.InterpolationMode = 'HighQualityBicubic'
                    $draw.PixelOffsetMode = 'HighQuality'
                    $draw.DrawImage($asset[1], [System.Drawing.Rectangle]::new(0, 0, $size, $size))
                    $bitmap.Save((Join-Path $directory $asset[0]), [System.Drawing.Imaging.ImageFormat]::Png)
                } finally {
                    $draw.Dispose()
                    $bitmap.Dispose()
                }
            }
        }
    } finally {
        $foreground.Dispose()
    }
} finally {
    $source.Dispose()
}
