#!/bin/bash
set -e

echo "🚀 Starting Release Verification..."

echo "🔒 Checking Package.resolved for dependency drift..."
swift package resolve 2>/dev/null
if ! git diff --quiet Package.resolved 2>/dev/null; then
    echo "⚠️  Package.resolved has drifted — commit the updated file before releasing."
fi

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
