#!/bin/bash

# Setup script to automatically ignore gas-reports and layout directories locally
# while keeping them available for GitHub workflows

set -e

PROTOCOL_DIR="packages/protocol"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "🔧 Setting up local git ignores..."

# Function to apply skip-worktree to a directory
apply_skip_worktree() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "  → Ignoring changes in $dir"
        find "$dir" -type f -exec git update-index --skip-worktree {} \; 2>/dev/null || true
    fi
}

# Apply to target directories
apply_skip_worktree "$PROTOCOL_DIR/gas-reports"
apply_skip_worktree "$PROTOCOL_DIR/layout"

echo "✅ Local git ignores configured successfully!"
echo ""
echo "📝 Note: Files in gas-reports/ and layout/ are now ignored locally"
echo "   but remain available for GitHub workflows and other developers."
echo ""
echo "🔄 To undo this setup, run: scripts/remove-local-ignores.sh"