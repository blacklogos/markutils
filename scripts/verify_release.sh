#!/bin/bash
set -e

echo "🚀 Starting Release Verification..."

echo "📦 Building Clip..."
swift build

echo "🧪 Running Tests..."
if swift test; then
    echo "✅ Release Verification passed! You are ready to ship."
else
    echo ""
    echo "❌ Tests Failed."
    echo "💡 TROUBLESHOOTING: If you see 'no such module XCTest', it means you are using the Command Line Tools SDK which excludes XCTest."
    echo "   Please install the full Xcode application from the Mac App Store to run the regression tests."
    exit 1
fi
