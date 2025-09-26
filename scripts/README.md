# Local Git Ignore Scripts

These scripts automatically configure git to ignore certain directories locally while keeping them available for GitHub workflows.

## Automatic Setup

The local ignores are automatically applied when developers run:
```bash
pnpm install
```

This happens transparently via the `postinstall` script in package.json.

## Manual Control

Developers can also manually control the ignores:

```bash
# Apply local ignores
pnpm run setup:ignores

# Remove local ignores
pnpm run remove:ignores
```

## What Gets Ignored

- `packages/protocol/gas-reports/` - Gas optimization reports
- `packages/protocol/layout/` - Contract layout files

## How It Works

Uses git's `skip-worktree` feature to:
- ✅ Ignore local changes to these files
- ✅ Keep files tracked in the repository
- ✅ Allow GitHub workflows to access/modify them
- ✅ Let other developers see changes normally

## Developer Experience

- No git status noise from auto-generated files
- Workflows continue working normally
- Optional - developers can opt-out anytime
- Completely reversible