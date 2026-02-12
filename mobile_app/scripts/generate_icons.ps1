# PowerShell script to generate app icons from SVG template
# Requires: ImageMagick (install via: choco install imagemagick)
# Run this script from the mobile_app directory

$ErrorActionPreference = "Stop"

# Ensure we're in the correct directory (where this script is located)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$svgPath = "assets/images/app_icon_template.svg"

if (-not (Test-Path $svgPath)) {
    Write-Host "ERROR: SVG template not found at $svgPath" -ForegroundColor Red
    exit 1
}

Write-Host "Generating app icons from SVG template..." -ForegroundColor Yellow
Write-Host ""

# Check if ImageMagick is available
$magickAvailable = $false
try {
    $null = Get-Command magick -ErrorAction Stop
    $magickAvailable = $true
} catch {
    Write-Host "ImageMagick not found. Trying alternative methods..." -ForegroundColor Yellow
}

if ($magickAvailable) {
    Write-Host "Using ImageMagick..." -ForegroundColor Green
    
    # Android icons
    Write-Host "Generating Android icons..." -ForegroundColor Cyan
    $androidSizes = @{
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" = 48
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" = 72
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" = 96
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" = 144
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
    }
    
    foreach ($icon in $androidSizes.GetEnumerator()) {
        $outputPath = $icon.Key
        $size = $icon.Value
        
        $dir = Split-Path -Parent $outputPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        magick convert -background none -resize "${size}x${size}" $svgPath $outputPath
        Write-Host "  Generated: $outputPath ($size x $size)" -ForegroundColor Gray
    }
    
    # Web icons
    Write-Host ""
    Write-Host "Generating Web icons..." -ForegroundColor Cyan
    $webSizes = @{
        "web/icons/Icon-192.png" = 192
        "web/icons/Icon-512.png" = 512
        "web/icons/Icon-maskable-192.png" = 192
        "web/icons/Icon-maskable-512.png" = 512
    }
    
    foreach ($icon in $webSizes.GetEnumerator()) {
        $outputPath = $icon.Key
        $size = $icon.Value
        
        $dir = Split-Path -Parent $outputPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        magick convert -background none -resize "${size}x${size}" $svgPath $outputPath
        Write-Host "  Generated: $outputPath ($size x $size)" -ForegroundColor Gray
    }
    
    # Web favicon
    Write-Host ""
    Write-Host "Generating favicon..." -ForegroundColor Cyan
    magick convert -background none -resize "32x32" $svgPath "web/favicon.png"
    Write-Host "  Generated: web/favicon.png (32 x 32)" -ForegroundColor Gray
    
} else {
    Write-Host ""
    Write-Host "ImageMagick not available. Please use one of these options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Install ImageMagick" -ForegroundColor Cyan
    Write-Host "  choco install imagemagick" -ForegroundColor White
    Write-Host "  Then run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 2: Use Inkscape" -ForegroundColor Cyan
    Write-Host "  1. Open $svgPath in Inkscape" -ForegroundColor White
    Write-Host "  2. File -> Export PNG Image" -ForegroundColor White
    Write-Host "  3. Export in the following sizes:" -ForegroundColor White
    Write-Host "     - Android: 48, 72, 96, 144, 192 px" -ForegroundColor White
    Write-Host "     - Web: 192, 512 px" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 3: Use online converter" -ForegroundColor Cyan
    Write-Host "  Upload $svgPath to convertio.co or cloudconvert.com" -ForegroundColor White
    Write-Host "  Export as PNG in required sizes" -ForegroundColor White
    Write-Host ""
    Write-Host "Required icon locations:" -ForegroundColor Yellow
    Write-Host "  Android:" -ForegroundColor Cyan
    Write-Host "    - android/app/src/main/res/mipmap-mdpi/ic_launcher.png (48x48)" -ForegroundColor White
    Write-Host "    - android/app/src/main/res/mipmap-hdpi/ic_launcher.png (72x72)" -ForegroundColor White
    Write-Host "    - android/app/src/main/res/mipmap-xhdpi/ic_launcher.png (96x96)" -ForegroundColor White
    Write-Host "    - android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png (144x144)" -ForegroundColor White
    Write-Host "    - android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png (192x192)" -ForegroundColor White
    Write-Host "  Web:" -ForegroundColor Cyan
    Write-Host "    - web/icons/Icon-192.png (192x192)" -ForegroundColor White
    Write-Host "    - web/icons/Icon-512.png (512x512)" -ForegroundColor White
    Write-Host "    - web/icons/Icon-maskable-192.png (192x192)" -ForegroundColor White
    Write-Host "    - web/icons/Icon-maskable-512.png (512x512)" -ForegroundColor White
    Write-Host "    - web/favicon.png (32x32)" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "All icons generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Rebuild the app: flutter clean && flutter build apk" -ForegroundColor White
Write-Host "  2. Check that icons appear correctly on the device" -ForegroundColor White

