#!/bin/bash
# Load environment variables from .env.local for build scripts
#
# Usage:
#   source scripts/load-env.sh
#   ./scripts/build-images.sh --push
#
# Or inline:
#   $(bash scripts/load-env.sh) && ./scripts/build-images.sh --push

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env.local"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -f "$ENV_FILE" ]]; then
    echo -e "${GREEN}Loading environment from .env.local${NC}"

    # Export all non-comment, non-empty lines as environment variables
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Export the variable
        export "$line"
    done < "$ENV_FILE"

    # Show what was loaded (without exposing values)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo -e "${GREEN}✓ GITHUB_TOKEN loaded (length: ${#GITHUB_TOKEN} chars)${NC}"
    fi
    if [[ -n "${GITHUB_USERNAME:-}" ]]; then
        echo -e "${GREEN}✓ GITHUB_USERNAME=$GITHUB_USERNAME${NC}"
    fi

    echo -e "${GREEN}Environment variables loaded successfully${NC}"
else
    echo -e "${YELLOW}Warning: .env.local not found${NC}"
    echo -e "${YELLOW}Create it from the template: cp .env.local.template .env.local${NC}"
    echo -e "${YELLOW}Then edit .env.local with your GITHUB_TOKEN${NC}"
fi

# If sourced, this will export variables to the parent shell
# If executed, this will just display the exports for eval
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced - variables are already exported
    :
else
    # Being executed - output exports for eval
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        echo "export $line"
    done < "$ENV_FILE" 2>/dev/null || true
fi
