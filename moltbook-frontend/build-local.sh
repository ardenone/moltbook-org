#!/bin/bash
# Local build script for testing frontend without Docker
# This script builds the Next.js application locally and can serve it
# Use this for testing when Docker builds are not available

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 Moltbook Frontend Local Build Script"
echo "========================================"

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo "❌ Node.js version 20+ required, but found $(node -v)"
    exit 1
fi
echo "✅ Node.js version: $(node -v)"

# Check pnpm
if ! command -v pnpm &> /dev/null; then
    echo "❌ pnpm not found. Installing globally..."
    npm install -g pnpm
fi
echo "✅ pnpm version: $(pnpm -v)"

# Clean previous build
echo ""
echo "🧹 Cleaning previous build artifacts..."
rm -rf .next out

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
pnpm install --frozen-lockfile

# Build the application
echo ""
echo "🏗️  Building Next.js application with Turbopack..."
NODE_OPTIONS='--max-old-space-size=4096' pnpm run build

# Check if build was successful
if [ -d ".next" ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "To start the production server, run:"
    echo "  cd $SCRIPT_DIR && pnpm start"
    echo ""
    echo "The application will be available at http://localhost:3000"
else
    echo ""
    echo "❌ Build failed - .next directory not found"
    exit 1
fi
