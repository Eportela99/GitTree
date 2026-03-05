#!/bin/bash
# ============================================================
# GitTree - Build Release Archive
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="$PROJECT_DIR/GitTree.xcodeproj"
SCHEME="GitTree"
ARCHIVE_PATH="$PROJECT_DIR/build/GitTree.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/export"
EXPORT_PLIST="$SCRIPT_DIR/ExportOptions.plist"

echo "============================================================"
echo "  GitTree Release Build"
echo "============================================================"
echo ""

# Step 0: Process icon (if Python + Pillow available)
if command -v python3 &>/dev/null; then
    echo "[1/4] Processing app icon..."
    python3 "$SCRIPT_DIR/process_icon.py" && echo "      Icon processed." || echo "      Icon processing skipped (Pillow may not be installed)."
else
    echo "[1/4] python3 not found — skipping icon processing"
fi
echo ""

# Step 1: Clean build folder
echo "[2/4] Cleaning previous build..."
rm -rf "$PROJECT_DIR/build"
mkdir -p "$PROJECT_DIR/build"
echo "      Done."
echo ""

# Step 2: Archive
echo "[3/4] Archiving (Release)..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    ENABLE_HARDENED_RUNTIME=YES \
    | grep -E "^(Archive|error:|warning:|Build succeeded|Build FAILED)" \
    || true

if [ -d "$ARCHIVE_PATH" ]; then
    echo "      Archive created: $ARCHIVE_PATH"
else
    echo "ERROR: Archive not created. Check Xcode for details."
    exit 1
fi
echo ""

# Step 3: Export
echo "[4/4] Exporting app..."

# Create export plist if it doesn't exist
if [ ! -f "$EXPORT_PLIST" ]; then
    cat > "$EXPORT_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST
fi

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    | grep -E "^(Export|error:|warning:|** EXPORT)" \
    || true

if [ -d "$EXPORT_PATH/GitTree.app" ]; then
    echo ""
    echo "============================================================"
    echo "  BUILD SUCCESSFUL"
    echo "  App: $EXPORT_PATH/GitTree.app"
    echo "============================================================"
else
    # Fallback: copy from archive
    echo "      Export step had issues. Copying from archive..."
    mkdir -p "$EXPORT_PATH"
    cp -R "$ARCHIVE_PATH/Products/Applications/GitTree.app" "$EXPORT_PATH/"
    echo ""
    echo "============================================================"
    echo "  BUILD COMPLETE (from archive)"
    echo "  App: $EXPORT_PATH/GitTree.app"
    echo "============================================================"
fi
