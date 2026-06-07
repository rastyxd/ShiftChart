#!/bin/bash
set -e

# Check if version arguments were passed (e.g., ./build.sh 1.0.3 4)
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Error: Please provide version name and build number."
    echo "Usage: ./build.sh <version_name> <build_number>"
    echo "Example: ./build.sh 1.0.3 4"
    exit 1
fi

VERSION_NAME=$1
BUILD_NUMBER=$2
TARGET_DIR="$HOME/shiftchart/release/$VERSION_NAME"

echo "📂 Creating release directory: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Building Release APK for version $VERSION_NAME+$BUILD_NUMBER..."
# This overrides pubspec.yaml values dynamically
flutter build apk --release --build-name="$VERSION_NAME" --build-number="$BUILD_NUMBER"

SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"
TARGET_APK="$TARGET_DIR/shiftchart-$VERSION_NAME.apk"

if [ -f "$SOURCE_APK" ]; then
    echo "💾 Copying APK to archive..."
    cp "$SOURCE_APK" "$TARGET_APK"
    
    echo "🔒 Generating SHA-1 and SHA-256 checksums..."
    echo "--- SHA-256 ---" > "$TARGET_DIR/checksums.txt"
    sha256sum "$TARGET_APK" | awk '{print $1 "  " "'shiftchart-$VERSION_NAME.apk'"}' >> "$TARGET_DIR/checksums.txt"
    
    echo -e "\n--- SHA-1 ---" >> "$TARGET_DIR/checksums.txt"
    sha1sum "$TARGET_APK" | awk '{print $1 "  " "'shiftchart-$VERSION_NAME.apk'"}' >> "$TARGET_DIR/checksums.txt"
    
    echo "✅ Release $VERSION_NAME ($BUILD_NUMBER) archived successfully with verification hashes!"
else
    echo "❌ Error: Release APK compilation failed."
    exit 1
fi
