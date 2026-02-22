#!/bin/bash

# ✅ StealthSeal Permission Bottom Sheet - File Verification Script
# This script verifies all required files are in place for the native Android permission dialog

echo "🔍 VERIFYING PERMISSION BOTTOM SHEET FILES..."
echo ""

ERRORS=0

# Check XML Layout Files
echo "📋 Checking Layout Files..."
if [ -f "android/app/src/main/res/layout/permission_bottom_sheet.xml" ]; then
    echo "  ✅ permission_bottom_sheet.xml"
else
    echo "  ❌ permission_bottom_sheet.xml MISSING"
    ERRORS=$((ERRORS + 1))
fi

# Check Drawable/Resource Files
echo ""
echo "🎨 Checking Drawable Files..."

DRAWABLES=(
    "android/app/src/main/res/drawable/permission_icon_background.xml"
    "android/app/src/main/res/drawable/badge_background.xml"
    "android/app/src/main/res/drawable/gradient_button_background.xml"
)

for drawable in "${DRAWABLES[@]}"; do
    if [ -f "$drawable" ]; then
        echo "  ✅ $(basename $drawable)"
    else
        echo "  ❌ $(basename $drawable) MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Animation Files
echo ""
echo "🎬 Checking Animation Files..."
if [ -f "android/app/src/main/res/anim/slide_up.xml" ]; then
    echo "  ✅ slide_up.xml"
else
    echo "  ❌ slide_up.xml MISSING"
    ERRORS=$((ERRORS + 1))
fi

# Check Kotlin Files
echo ""
echo "⚙️  Checking Kotlin Files..."

KOTLIN_FILES=(
    "android/app/src/main/kotlin/com/example/stealthseal/PermissionBottomSheetHelper.kt"
    "android/app/src/main/kotlin/com/example/stealthseal/AppLockActivity_Updated_Example.kt"
)

for kotlin_file in "${KOTLIN_FILES[@]}"; do
    if [ -f "$kotlin_file" ]; then
        echo "  ✅ $(basename $kotlin_file)"
    else
        echo "  ❌ $(basename $kotlin_file) MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Documentation
echo ""
echo "📚 Checking Documentation..."

DOCS=(
    "android/app/src/main/kotlin/com/example/stealthseal/PERMISSION_DIALOG_INTEGRATION.md"
    "PERMISSION_BOTTOM_SHEET_IMPLEMENTATION.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        echo "  ✅ $(basename $doc)"
    else
        echo "  ❌ $(basename $doc) MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

# Summary
echo ""
echo "════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "✅ ALL FILES VERIFIED SUCCESSFULLY!"
    echo "════════════════════════════════════════════"
    echo ""
    echo "Next Steps:"
    echo "  1. Update AppLockActivity.kt with integration code"
    echo "  2. Run: flutter clean && flutter pub get"
    echo "  3. Run: flutter build apk --debug"
    echo "  4. Test on device/emulator"
    echo ""
    exit 0
else
    echo "❌ $ERRORS FILE(S) MISSING!"
    echo "════════════════════════════════════════════"
    echo ""
    echo "Please check the file paths above."
    echo ""
    exit 1
fi
