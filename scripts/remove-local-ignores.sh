#!/bin/bash

# Script to remove local git ignores for gas-reports and layout directories

set -e

PROTOCOL_DIR="packages/protocol"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "🔧 Removing local git ignores..."

# Function to remove skip-worktree from a directory
remove_skip_worktree() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "  → Re-enabling tracking for $dir"
        find "$dir" -type f -exec git update-index --no-skip-worktree {} \; 2>/dev/null || true
    fi
}

# Remove from target directories
remove_skip_worktree "$PROTOCOL_DIR/gas-reports"
remove_skip_worktree "$PROTOCOL_DIR/layout"

# Remove from *_Layout.sol files using pattern matching
if git ls-files "$PROTOCOL_DIR/contracts/**/*_Layout.sol" &>/dev/null; then
    echo "  → Re-enabling tracking for *_Layout.sol files"
    git ls-files "$PROTOCOL_DIR/contracts/**/*_Layout.sol" | xargs git update-index --no-skip-worktree 2>/dev/null || true
fi

echo "✅ Local git ignores removed successfully!"
echo ""
echo "📝 Note: Files in gas-reports/, layout/, and *_Layout.sol files are now tracked normally"