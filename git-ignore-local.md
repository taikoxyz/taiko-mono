# Local Git Ignore Commands

## What was done:
Files in `packages/protocol/gas-reports/` and `packages/protocol/layout/` are now ignored locally using git's `skip-worktree` feature.

## Useful commands:

### Check which files are currently skip-worktree:
```bash
git ls-files -v | grep "^S"
```

### To undo skip-worktree for specific files:
```bash
git update-index --no-skip-worktree packages/protocol/gas-reports/filename.md
```

### To undo skip-worktree for entire directories:
```bash
find packages/protocol/gas-reports/ -type f -exec git update-index --no-skip-worktree {} \;
find packages/protocol/layout/ -type f -exec git update-index --no-skip-worktree {} \;
```

### To add skip-worktree for new files in these directories:
```bash
find packages/protocol/gas-reports/ -type f -exec git update-index --skip-worktree {} \;
find packages/protocol/layout/ -type f -exec git update-index --skip-worktree {} \;
```

## How it works:
- Files remain tracked in the repository
- GitHub workflows can still access and modify these files
- Local changes to these files are ignored by git status/add/commit
- Other developers and CI/CD systems see the files normally