#!/bin/bash
# pnpm helper script for moltbook-frontend
# Workaround for devpod filesystem issues affecting npm install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PNPM_BIN="/home/coder/.local/share/pnpm/.tools/pnpm-exe/10.28.2/pnpm"

# Main function
main() {
    local cmd="${1:-install}"
    cd "$PROJECT_DIR"

    case "$cmd" in
        install)
            echo "Installing dependencies with pnpm..."
            "$PNPM_BIN" install --shamefully-hoist --force
            ;;
        build)
            echo "Building with pnpm..."
            "$PNPM_BIN" run build
            ;;
        dev)
            echo "Starting dev server..."
            "$PNPM_BIN" run dev
            ;;
        docker-build)
            echo "Building in Docker (recommended for filesystem issues)..."
            docker run --rm -v "$PROJECT_DIR:/app" -w /app node:20-alpine sh -c "corepack enable && pnpm install && pnpm run build"
            ;;
        docker-install)
            echo "Installing dependencies in Docker..."
            docker run --rm -v "$PROJECT_DIR:/app" -w /app node:20-alpine sh -c "corepack enable && pnpm install"
            ;;
        *)
            echo "Usage: $0 {install|build|dev|docker-build|docker-install}"
            exit 1
            ;;
    esac
}

main "$@"
