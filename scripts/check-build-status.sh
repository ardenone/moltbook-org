#!/bin/bash
# Check Docker image build status and help developers understand the workflow

set -e

echo "======================================"
echo "Moltbook Docker Build Status Checker"
echo "======================================"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is authenticated"
echo ""

# Check recent workflow runs
echo "📋 Recent Build Workflow Runs:"
echo "------------------------------"
gh run list --workflow=build-push.yml --limit 5 || {
    echo "❌ Failed to fetch workflow runs"
    exit 1
}
echo ""

# Get the latest run
LATEST_RUN=$(gh run list --workflow=build-push.yml --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$LATEST_RUN" ]; then
    echo "⚠️  No workflow runs found"
    echo ""
    echo "To trigger a build:"
    echo "  gh workflow run build-push.yml"
    exit 0
fi

echo "🔍 Latest Workflow Run Details:"
echo "------------------------------"
gh run view "$LATEST_RUN"
echo ""

# Check if the latest run is still in progress
STATUS=$(gh run view "$LATEST_RUN" --json status --jq '.status')

if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
    echo "⏳ Build is currently running..."
    echo ""
    echo "To watch the build in real-time:"
    echo "  gh run watch $LATEST_RUN"
    exit 0
fi

# Check if the latest run was successful
CONCLUSION=$(gh run view "$LATEST_RUN" --json conclusion --jq '.conclusion')

if [ "$CONCLUSION" = "success" ]; then
    echo "✅ Latest build was successful!"
    echo ""
    echo "Images built:"
    echo "  - ghcr.io/ardenone/moltbook-api:latest"
    echo "  - ghcr.io/ardenone/moltbook-frontend:latest"
    echo ""
    echo "Check images at: https://github.com/ardenone?tab=packages"
elif [ "$CONCLUSION" = "failure" ]; then
    echo "❌ Latest build failed"
    echo ""
    echo "To view logs:"
    echo "  gh run view $LATEST_RUN --log"
    echo ""
    echo "To trigger a new build:"
    echo "  gh workflow run build-push.yml"
else
    echo "⚠️  Latest build status: $CONCLUSION"
fi

echo ""
echo "======================================"
echo "Need Help?"
echo "======================================"
echo "Read: DOCKER_BUILD.md for detailed documentation"
echo ""
echo "Common Commands:"
echo "  - Trigger new build: gh workflow run build-push.yml"
echo "  - Watch running build: gh run watch"
echo "  - View build logs: gh run view <run-id> --log"
echo "  - List all runs: gh run list --workflow=build-push.yml"
