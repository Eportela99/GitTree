#!/bin/bash
# ============================================================
# GitTree - Package as .pkg Installer
# Run AFTER build_release.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="$PROJECT_DIR/build/export/GitTree.app"
PKG_OUTPUT="$PROJECT_DIR/build/GitTree.pkg"
VERSION="1.0"
BUNDLE_ID="com.elportela.GitTree"

echo "============================================================"
echo "  GitTree - Package Installer"
echo "============================================================"
echo ""

# Check app exists
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Run scripts/build_release.sh first."
    exit 1
fi

echo "App found: $APP_PATH"
echo ""

# Step 1: Build component package
echo "[1/2] Building component package..."
COMPONENT_PKG="$PROJECT_DIR/build/GitTree_component.pkg"

pkgbuild \
    --component "$APP_PATH" \
    --install-location "/Applications" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    "$COMPONENT_PKG"

echo "      Component package: $COMPONENT_PKG"
echo ""

# Step 2: Build product package (installer)
echo "[2/2] Building product package..."

# Create distribution XML
DIST_XML="$PROJECT_DIR/build/distribution.xml"
cat > "$DIST_XML" << XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>GitTree</title>
    <welcome file="Welcome.rtf" mime-type="text/rtf"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$BUNDLE_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$BUNDLE_ID" visible="false">
        <pkg-ref id="$BUNDLE_ID"/>
    </choice>
    <pkg-ref id="$BUNDLE_ID" version="$VERSION" onConclusion="none">GitTree_component.pkg</pkg-ref>
</installer-gui-script>
XML

# Create a simple welcome RTF
WELCOME_RTF="$PROJECT_DIR/build/Welcome.rtf"
cat > "$WELCOME_RTF" << 'RTF'
{\rtf1\ansi\ansicpg1252\cocoartf2639
{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx566\tx1133\tx1700\tx2267\tx2834\tx3401\tx3968\tx4535\tx5102\tx5669\tx6236\tx6803\pardirnatural\partightenfactor0
\f0\fs28 \cf0 Welcome to GitTree\
\
\fs22 GitTree is a visual Git & GitHub manager for macOS.\
\
It will be installed in your Applications folder.\
\
Requirements:\
- macOS 13.0 or later\
- Git (included with Xcode Command Line Tools)\
- GitHub CLI (gh) for GitHub features: brew install gh\
}
RTF

productbuild \
    --distribution "$DIST_XML" \
    --package-path "$PROJECT_DIR/build" \
    --resources "$PROJECT_DIR/build" \
    "$PKG_OUTPUT"

echo ""
echo "============================================================"
echo "  PACKAGE CREATED"
echo "  PKG: $PKG_OUTPUT"
echo ""
echo "  To install: double-click GitTree.pkg"
echo "  Or: sudo installer -pkg $PKG_OUTPUT -target /"
echo "============================================================"
