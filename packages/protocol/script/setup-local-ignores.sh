#!/bin/bash

# Setup Local Git Ignores for Generated Files
#
# This script marks auto-generated files to be ignored locally using git's skip-worktree feature.
# These files will still be tracked in CI and committed automatically by the GitHub workflow.
#
# Usage: ./script/setup-local-ignores.sh

set -e

echo "Setting up local git ignores for generated files..."

# Mark all *_Layout.sol files to be ignored locally using git pattern matching
layout_files=$(git ls-files 'contracts/**/*_Layout.sol' 2>/dev/null || true)

if [ -n "$layout_files" ]; then
    echo "$layout_files" | xargs git update-index --skip-worktree
    count=$(echo "$layout_files" | wc -l | tr -d ' ')
    echo "✅ Marked $count *_Layout.sol files to skip locally"
else
    echo "ℹ️  No *_Layout.sol files found"
fi

# Optionally mark other generated directories
if [ -d "gas-reports" ]; then
    git ls-files gas-reports/ | xargs -r git update-index --skip-worktree || true
    echo "✅ Marked gas-reports/ to skip locally"
fi

if [ -d "snapshots" ]; then
    git ls-files snapshots/ | xargs -r git update-index --skip-worktree || true
    echo "✅ Marked snapshots/ to skip locally"
fi

echo ""
echo "=========================================="
echo "✅ Local ignores configured successfully!"
echo ""
echo "These files will be ignored in your local git status,"
echo "but the GitHub CI workflow will still track and commit them."
echo ""
echo "To undo this setup, run:"
echo "  git ls-files 'contracts/**/*_Layout.sol' | xargs git update-index --no-skip-worktree"
