# ✅ StealthSeal Permission Bottom Sheet - File Verification Script (PowerShell)
# This script verifies all required files are in place for the native Android permission dialog

Write-Host "🔍 VERIFYING PERMISSION BOTTOM SHEET FILES..." -ForegroundColor Cyan
Write-Host ""

$errors = 0
$baseDir = Get-Location

# Check XML Layout Files
Write-Host "📋 Checking Layout Files..." -ForegroundColor Yellow

$layoutFile = "android/app/src/main/res/layout/permission_bottom_sheet.xml"
if (Test-Path $layoutFile) {
    Write-Host "  ✅ permission_bottom_sheet.xml" -ForegroundColor Green
} else {
    Write-Host "  ❌ permission_bottom_sheet.xml MISSING" -ForegroundColor Red
    $errors += 1
}

# Check Drawable/Resource Files
Write-Host ""
Write-Host "🎨 Checking Drawable Files..." -ForegroundColor Yellow

$drawables = @(
    "android/app/src/main/res/drawable/permission_icon_background.xml",
    "android/app/src/main/res/drawable/badge_background.xml",
    "android/app/src/main/res/drawable/gradient_button_background.xml"
)

foreach ($drawable in $drawables) {
    $filename = Split-Path -Leaf $drawable
    if (Test-Path $drawable) {
        Write-Host "  ✅ $filename" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $filename MISSING" -ForegroundColor Red
        $errors += 1
    }
}

# Check Animation Files
Write-Host ""
Write-Host "🎬 Checking Animation Files..." -ForegroundColor Yellow

$animFile = "android/app/src/main/res/anim/slide_up.xml"
if (Test-Path $animFile) {
    Write-Host "  ✅ slide_up.xml" -ForegroundColor Green
} else {
    Write-Host "  ❌ slide_up.xml MISSING" -ForegroundColor Red
    $errors += 1
}

# Check Kotlin Files
Write-Host ""
Write-Host "⚙️  Checking Kotlin Files..." -ForegroundColor Yellow

$kotlinFiles = @(
    "android/app/src/main/kotlin/com/example/stealthseal/PermissionBottomSheetHelper.kt",
    "android/app/src/main/kotlin/com/example/stealthseal/AppLockActivity_Updated_Example.kt"
)

foreach ($kotlin in $kotlinFiles) {
    $filename = Split-Path -Leaf $kotlin
    if (Test-Path $kotlin) {
        Write-Host "  ✅ $filename" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $filename MISSING" -ForegroundColor Red
        $errors += 1
    }
}

# Check Documentation
Write-Host ""
Write-Host "📚 Checking Documentation..." -ForegroundColor Yellow

$docs = @(
    "android/app/src/main/kotlin/com/example/stealthseal/PERMISSION_DIALOG_INTEGRATION.md",
    "PERMISSION_BOTTOM_SHEET_IMPLEMENTATION.md"
)

foreach ($doc in $docs) {
    $filename = Split-Path -Leaf $doc
    if (Test-Path $doc) {
        Write-Host "  ✅ $filename" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $filename MISSING" -ForegroundColor Red
        $errors += 1
    }
}

# Summary
Write-Host ""
Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan

if ($errors -eq 0) {
    Write-Host "✅ ALL FILES VERIFIED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Update AppLockActivity.kt with integration code" -ForegroundColor White
    Write-Host "  2. Run: flutter clean && flutter pub get" -ForegroundColor White
    Write-Host "  3. Run: flutter build apk --debug" -ForegroundColor White
    Write-Host "  4. Test on device/emulator" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ $errors FILE(S) MISSING!" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please check the file paths above." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
