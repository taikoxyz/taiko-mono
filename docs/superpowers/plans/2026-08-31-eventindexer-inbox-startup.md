# Eventindexer Inbox Startup Regression Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Shasta Inbox configuration contract and make eventindexer startup choose its initial block correctly for L1, L2, sync, resync, and checkpointed databases.

**Architecture:** Replace the mistakenly retained `L1_TAIKO_ADDRESS` input with the existing deployment-facing `SHASTA_INBOX_ADDRESS`, validate the layer-specific requirement before opening external resources, and create the Inbox binding only for L1. Separate initial-block selection from assignment so a small unexported resolver can be table-tested with explicit repository and Shasta-height callbacks.

**Tech Stack:** Go 1.26, urfave/cli v2, go-ethereum contract bindings, testify, GitHub CLI.

## Global Constraints

- Preserve L1 Shasta `Proposed` and `Proved` filtering through the existing generated Inbox binding.
- Preserve checkpoint rewind behavior exactly as `latest - 1`.
- Do not add an L1 RPC client or Inbox dependency to L2.
- Do not change timestamp-to-block search, filtering, persistence, replay, or reorg behavior.
- Do not change `k8s-configs`.
- Keep `SHASTA_INBOX_ADDRESS` compatible with current deployment charts.
- Remove the complete `docs/superpowers` directory before creating the draft pull request.
- Use test-first red-green cycles and commit each independently reviewable change.

## File Map

- `packages/eventindexer/cmd/flags/indexer.go`: owns the indexer CLI/environment contract; restore `ShastaInboxAddress` and remove `L1TaikoAddress`.
- `packages/eventindexer/errors.go`: owns stable package validation errors; add `ErrNoShastaInboxAddress`.
- `packages/eventindexer/indexer/config.go`: owns parsed indexer configuration and pre-resource validation.
- `packages/eventindexer/indexer/config_test.go`: covers flag parsing, conditional Inbox requirements, and validation ordering.
- `packages/eventindexer/indexer/indexer.go`: owns resource construction; validate first and bind Inbox only for L1.
- `packages/eventindexer/indexer/set_initial_processing_block_height.go`: owns the startup decision table and final cursor assignment.
- `packages/eventindexer/indexer/set_initial_processing_block_height_test.go`: isolates every decision-table branch and verifies call counts.
- `packages/eventindexer/.default.env`: L1-default example; remove stale `L1_TAIKO_ADDRESS` and retain Shasta Inbox input.
- `packages/eventindexer/.l1.env`: explicit L1 example with the same corrected contract.
- `packages/eventindexer/.l2.env`: must remain free of Inbox configuration.
- `packages/eventindexer/README.md`: documents the layer-specific requirement and checkpoint behavior.
- `docs/superpowers/specs/2026-08-31-eventindexer-inbox-startup-design.md`: temporary approved design; delete before draft PR.
- `docs/superpowers/plans/2026-08-31-eventindexer-inbox-startup.md`: this temporary execution plan; delete before draft PR.

---

### Task 1: Restore and validate the Shasta Inbox configuration contract

**Files:**

- Modify: `packages/eventindexer/indexer/config_test.go:3-90`
- Modify: `packages/eventindexer/cmd/flags/indexer.go:26-32,87-99`
- Modify: `packages/eventindexer/errors.go:5-27`
- Modify: `packages/eventindexer/indexer/config.go:14-85`
- Modify: `packages/eventindexer/indexer/indexer.go:116-177`

**Interfaces:**

- Produces: `flags.ShastaInboxAddress *cli.StringFlag` with CLI name `shastaInboxAddress` and environment variable `SHASTA_INBOX_ADDRESS`.
- Produces: `eventindexer.ErrNoShastaInboxAddress` with key `ERR_NO_SHASTA_INBOX_ADDRESS`.
- Produces: `Config.ShastaInboxAddress common.Address`.
- Produces: `func (c *Config) validate() error`.
- Consumes: existing `Layer1`, `Layer2`, `Sync`, `Resync`, and `ZeroAddress` values from the `indexer` package.

- [ ] **Step 1: Replace the parsing assertion and add failing validation tests**

In `config_test.go`, rename the fixture to `shastaInboxAddress`, replace the existing `L1TaikoAddress` assertion and CLI argument with `ShastaInboxAddress`, add the root eventindexer and DB imports, and add these tests:

```go
func TestConfigValidate(t *testing.T) {
	tests := []struct {
		name    string
		cfg     *Config
		wantErr error
	}{
		{
			name: "l1 requires Shasta inbox",
			cfg: &Config{
				Layer:    Layer1,
				SyncMode: Sync,
			},
			wantErr: eventindexer.ErrNoShastaInboxAddress,
		},
		{
			name: "l1 accepts Shasta inbox",
			cfg: &Config{
				Layer:                Layer1,
				SyncMode:             Sync,
				ShastaInboxAddress: common.HexToAddress(shastaInboxAddress),
			},
		},
		{
			name: "l2 does not require Shasta inbox",
			cfg: &Config{
				Layer:    Layer2,
				SyncMode: Sync,
			},
		},
		{
			name: "invalid sync mode",
			cfg: &Config{
				Layer:    Layer2,
				SyncMode: SyncMode("invalid"),
			},
			wantErr: eventindexer.ErrInvalidMode,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.validate()
			if tt.wantErr == nil {
				assert.NoError(t, err)
				return
			}
			assert.ErrorIs(t, err, tt.wantErr)
		})
	}
}

func TestInitFromConfigValidatesBeforeOpeningDatabase(t *testing.T) {
	databaseOpened := false
	cfg := &Config{
		Layer:    Layer1,
		SyncMode: Sync,
		OpenDBFunc: func() (db.DB, error) {
			databaseOpened = true
			return nil, nil
		},
	}

	err := InitFromConfig(context.Background(), new(Indexer), cfg)

	assert.ErrorIs(t, err, eventindexer.ErrNoShastaInboxAddress)
	assert.False(t, databaseOpened)
}
```

The updated parsing assertion and argument are:

```go
assert.Equal(t, common.HexToAddress(shastaInboxAddress), c.ShastaInboxAddress)
```

```go
"--" + flags.ShastaInboxAddress.Name, shastaInboxAddress,
```

- [ ] **Step 2: Run the focused tests and verify the red state**

Run:

```bash
go test ./packages/eventindexer/indexer -run 'Test(NewConfigFromCliContext|ConfigValidate|InitFromConfigValidatesBeforeOpeningDatabase)$'
```

Expected: compilation fails because `ShastaInboxAddress`, `ErrNoShastaInboxAddress`, and `validate` do not exist yet.

- [ ] **Step 3: Restore the flag, config field, and stable validation error**

Replace `L1TaikoAddress` in `cmd/flags/indexer.go` with:

```go
ShastaInboxAddress = &cli.StringFlag{
	Name:     "shastaInboxAddress",
	Usage:    "Address of the Shasta Inbox contract",
	Required: false,
	Category: indexerCategory,
	EnvVars:  []string{"SHASTA_INBOX_ADDRESS"},
}
```

Place `ShastaInboxAddress` in `IndexerFlags` where `L1TaikoAddress` was.

Add this package error in `packages/eventindexer/errors.go`:

```go
ErrNoShastaInboxAddress = errors.Validation.NewWithKeyAndDetail(
	"ERR_NO_SHASTA_INBOX_ADDRESS",
	"ShastaInboxAddress is required for L1 indexing",
)
```

In `Config`, replace `L1TaikoAddress` with:

```go
ShastaInboxAddress common.Address
```

In `NewConfigFromCliContext`, parse it with:

```go
ShastaInboxAddress: common.HexToAddress(c.String(flags.ShastaInboxAddress.Name)),
```

Add validation below the `Config` type:

```go
func (c *Config) validate() error {
	switch c.SyncMode {
	case Sync, Resync:
	default:
		return eventindexer.ErrInvalidMode
	}

	if c.Layer == Layer1 && c.ShastaInboxAddress == ZeroAddress {
		return eventindexer.ErrNoShastaInboxAddress
	}

	return nil
}
```

Add the root eventindexer import to `config.go` for these errors.

- [ ] **Step 4: Validate before resources and bind Inbox only for L1**

At the first line of `InitFromConfig`, before `cfg.OpenDBFunc()`, add:

```go
if err := cfg.validate(); err != nil {
	return err
}
```

Replace the current Inbox construction block with:

```go
var inboxContract *inbox.Inbox

if cfg.Layer == Layer1 {
	slog.Info("setting shastaInboxAddress", "addr", cfg.ShastaInboxAddress.Hex())

	inboxContract, err = inbox.NewInbox(cfg.ShastaInboxAddress, ethClient)
	if err != nil {
		return errors.Wrap(err, "inbox.NewInbox")
	}
}
```

This intentionally ignores a stray Shasta address for L2 and leaves the generated binding available to the existing L1 filter loop.

- [ ] **Step 5: Format and run the green tests**

Run:

```bash
gofmt -w packages/eventindexer/cmd/flags/indexer.go packages/eventindexer/errors.go packages/eventindexer/indexer/config.go packages/eventindexer/indexer/config_test.go packages/eventindexer/indexer/indexer.go
go test ./packages/eventindexer/indexer -run 'Test(NewConfigFromCliContext|ConfigValidate|InitFromConfigValidatesBeforeOpeningDatabase)$'
```

Expected: all three focused tests pass.

- [ ] **Step 6: Commit the configuration contract fix**

```bash
git add packages/eventindexer/cmd/flags/indexer.go packages/eventindexer/errors.go packages/eventindexer/indexer/config.go packages/eventindexer/indexer/config_test.go packages/eventindexer/indexer/indexer.go
git commit -m "fix(eventindexer): restore Shasta inbox configuration"
```

---

### Task 2: Make initial-block selection layer-aware and checkpoint-first

**Files:**

- Create: `packages/eventindexer/indexer/set_initial_processing_block_height_test.go`
- Modify: `packages/eventindexer/indexer/set_initial_processing_block_height.go:11-44`

**Interfaces:**

- Produces: `func (i *Indexer) initialIndexingBlockByMode(ctx context.Context, mode SyncMode, firstShastaBlock func(context.Context) (uint64, error)) (uint64, error)`.
- Consumes: `eventindexer.EventRepository.FindLatestBlockID(context.Context, uint64) (uint64, error)`.
- Consumes: existing `func (i *Indexer) getFirstShastaBlockHeight(context.Context) (uint64, error)` without changing its contract.

- [ ] **Step 1: Add a failing decision-table test**

Create `set_initial_processing_block_height_test.go` with:

```go
package indexer

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type initialBlockEventRepository struct {
	eventindexer.EventRepository
	latest uint64
	err    error
	calls  int
}

func (r *initialBlockEventRepository) FindLatestBlockID(
	context.Context,
	uint64,
) (uint64, error) {
	r.calls++
	return r.latest, r.err
}

func TestInitialIndexingBlockByMode(t *testing.T) {
	repositoryErr := errors.New("repository failed")
	inboxErr := errors.New("inbox failed")

	tests := []struct {
		name           string
		layer          string
		mode           SyncMode
		latest         uint64
		repositoryErr  error
		firstHeight    uint64
		firstErr       error
		wantHeight     uint64
		wantErr        error
		wantRepoCalls  int
		wantFirstCalls int
	}{
		{name: "l1 sync resumes checkpoint", layer: Layer1, mode: Sync, latest: 10, wantHeight: 9, wantRepoCalls: 1},
		{name: "l2 sync resumes checkpoint", layer: Layer2, mode: Sync, latest: 10, wantHeight: 9, wantRepoCalls: 1},
		{name: "l2 sync empty database", layer: Layer2, mode: Sync, wantRepoCalls: 1},
		{name: "l2 resync", layer: Layer2, mode: Resync},
		{name: "l1 sync empty database", layer: Layer1, mode: Sync, firstHeight: 100, wantHeight: 100, wantRepoCalls: 1, wantFirstCalls: 1},
		{name: "l1 resync", layer: Layer1, mode: Resync, firstHeight: 100, wantHeight: 100, wantFirstCalls: 1},
		{name: "invalid mode", layer: Layer1, mode: SyncMode("invalid"), wantErr: eventindexer.ErrInvalidMode},
		{name: "repository error", layer: Layer1, mode: Sync, repositoryErr: repositoryErr, wantErr: repositoryErr, wantRepoCalls: 1},
		{name: "inbox error", layer: Layer1, mode: Resync, firstErr: inboxErr, wantErr: inboxErr, wantFirstCalls: 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repository := &initialBlockEventRepository{
				latest: tt.latest,
				err:    tt.repositoryErr,
			}
			indexer := &Indexer{
				eventRepo:  repository,
				layer:      tt.layer,
				srcChainID: 1,
			}
			firstCalls := 0
			firstShastaBlock := func(context.Context) (uint64, error) {
				firstCalls++
				return tt.firstHeight, tt.firstErr
			}

			got, err := indexer.initialIndexingBlockByMode(
				context.Background(), tt.mode, firstShastaBlock,
			)

			if tt.wantErr == nil {
				assert.NoError(t, err)
			} else {
				assert.ErrorIs(t, err, tt.wantErr)
			}
			assert.Equal(t, tt.wantHeight, got)
			assert.Equal(t, tt.wantRepoCalls, repository.calls)
			assert.Equal(t, tt.wantFirstCalls, firstCalls)
		})
	}
}
```

- [ ] **Step 2: Run the new test and verify the red state**

```bash
go test ./packages/eventindexer/indexer -run '^TestInitialIndexingBlockByMode$'
```

Expected: compilation fails because `initialIndexingBlockByMode` does not exist.

- [ ] **Step 3: Implement the decision helper and keep assignment in the existing method**

Replace the body of `setInitialIndexingBlockByMode` and add the helper immediately below it:

```go
func (i *Indexer) setInitialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
) error {
	startingBlock, err := i.initialIndexingBlockByMode(
		ctx,
		mode,
		i.getFirstShastaBlockHeight,
	)
	if err != nil {
		return err
	}

	slog.Info("startingBlock", "startingBlock", startingBlock)
	i.latestIndexedBlockNumber = startingBlock

	return nil
}

func (i *Indexer) initialIndexingBlockByMode(
	ctx context.Context,
	mode SyncMode,
	firstShastaBlock func(context.Context) (uint64, error),
) (uint64, error) {
	switch mode {
	case Sync, Resync:
	default:
		return 0, eventindexer.ErrInvalidMode
	}

	if mode == Sync {
		latest, err := i.eventRepo.FindLatestBlockID(ctx, i.srcChainID)
		if err != nil {
			return 0, errors.Wrap(err, "svc.eventRepo.FindLatestBlockID")
		}
		if latest != 0 {
			return latest - 1, nil
		}
	}

	if i.layer == Layer2 {
		return 0, nil
	}

	return firstShastaBlock(ctx)
}
```

Do not change `getFirstShastaBlockHeight`; it remains the production resolver for L1 first sync and resync.

- [ ] **Step 4: Format and run the decision-table and config tests**

```bash
gofmt -w packages/eventindexer/indexer/set_initial_processing_block_height.go packages/eventindexer/indexer/set_initial_processing_block_height_test.go
go test ./packages/eventindexer/indexer -run 'Test(InitialIndexingBlockByMode|ConfigValidate|InitFromConfigValidatesBeforeOpeningDatabase|NewConfigFromCliContext)$'
```

Expected: every listed test passes, including zero Inbox calls for checkpointed sync and all L2 branches.

- [ ] **Step 5: Commit the startup routing fix**

```bash
git add packages/eventindexer/indexer/set_initial_processing_block_height.go packages/eventindexer/indexer/set_initial_processing_block_height_test.go
git commit -m "fix(eventindexer): make startup block selection layer-aware"
```

---

### Task 3: Align tracked environment examples and README

**Files:**

- Modify: `packages/eventindexer/.default.env:11-12`
- Modify: `packages/eventindexer/.l1.env:11-12`
- Verify unchanged: `packages/eventindexer/.l2.env`
- Modify: `packages/eventindexer/README.md:7-13`

**Interfaces:**

- Consumes: `SHASTA_INBOX_ADDRESS` from Task 1.
- Produces: an operator-facing configuration contract matching the binary and current charts.

- [ ] **Step 1: Demonstrate the stale tracked configuration**

```bash
rg -n 'L1_TAIKO_ADDRESS|SHASTA_INBOX_ADDRESS' packages/eventindexer/.default.env packages/eventindexer/.l1.env packages/eventindexer/.l2.env packages/eventindexer/README.md
```

Expected: `.default.env` and `.l1.env` contain both variables, while README does not explain either layer-specific behavior.

- [ ] **Step 2: Remove stale variables and document the conditional requirement**

Delete the `L1_TAIKO_ADDRESS=...` lines from `.default.env` and `.l1.env`. Keep the existing `SHASTA_INBOX_ADDRESS=` lines. Do not add an Inbox variable to `.l2.env`.

Add this section after the README running instructions:

```markdown
## Layer-specific Inbox configuration

Set `LAYER=l1` with `SHASTA_INBOX_ADDRESS` pointing to the Shasta Inbox on the
source L1. The L1 indexer uses this binding to filter `Proposed` and `Proved`
events. A checkpointed `SYNC_MODE=sync` resumes from the database without
calling `activationTimestamp()`; a fresh sync or `resync` uses that timestamp
to find the first Shasta block.

Set `LAYER=l2` without `SHASTA_INBOX_ADDRESS`. The L2 indexer starts from its
database checkpoint or block zero and never queries an L1 Inbox.
```

- [ ] **Step 3: Verify the old contract is gone and the new contract is complete**

```bash
if rg -n 'L1TaikoAddress|l1TaikoAddress|L1_TAIKO_ADDRESS' packages/eventindexer; then exit 1; fi
rg -n 'ShastaInboxAddress|shastaInboxAddress|SHASTA_INBOX_ADDRESS' packages/eventindexer/cmd/flags/indexer.go packages/eventindexer/indexer packages/eventindexer/.default.env packages/eventindexer/.l1.env packages/eventindexer/README.md
if rg -n 'SHASTA_INBOX_ADDRESS' packages/eventindexer/.l2.env; then exit 1; fi
```

Expected: the first and third searches produce no matches; the middle search shows the flag, config, tests, L1 examples, and README.

- [ ] **Step 4: Run the focused package tests and commit documentation**

```bash
go test ./packages/eventindexer/indexer
git add packages/eventindexer/.default.env packages/eventindexer/.l1.env packages/eventindexer/README.md
git commit -m "docs(eventindexer): document layer-specific inbox config"
```

Expected: indexer tests pass and `.l2.env` remains unchanged.

---

### Task 4: Run full verification and remove temporary superpowers documents

**Files:**

- Delete: `docs/superpowers/specs/2026-08-31-eventindexer-inbox-startup-design.md`
- Delete: `docs/superpowers/plans/2026-08-31-eventindexer-inbox-startup.md`

**Interfaces:**

- Consumes: all production, test, and documentation changes from Tasks 1-3.
- Produces: a verified branch whose final tree contains no `docs/superpowers` path.

- [ ] **Step 1: Run fresh formatting, targeted tests, and package compilation**

```bash
gofmt -w packages/eventindexer/cmd/flags/indexer.go packages/eventindexer/errors.go packages/eventindexer/indexer/config.go packages/eventindexer/indexer/config_test.go packages/eventindexer/indexer/indexer.go packages/eventindexer/indexer/set_initial_processing_block_height.go packages/eventindexer/indexer/set_initial_processing_block_height_test.go
go test ./packages/eventindexer/indexer
go test ./packages/eventindexer/... -run '^$'
git diff --check
```

Expected: formatting makes no further semantic changes, both Go commands pass, and `git diff --check` prints nothing.

- [ ] **Step 2: Run the repository-configured eventindexer lint when installed**

```bash
if command -v golangci-lint >/dev/null 2>&1; then (cd packages/eventindexer && golangci-lint run --config=.golangci.yml --timeout=10m); else echo 'SKIP: golangci-lint is not installed locally'; fi
```

Expected: lint passes, or the command reports the explicit local-tool skip that will be covered by PR CI.

- [ ] **Step 3: Delete both temporary documents and their empty directories**

Use `apply_patch` to delete these exact files:

```text
docs/superpowers/specs/2026-08-31-eventindexer-inbox-startup-design.md
docs/superpowers/plans/2026-08-31-eventindexer-inbox-startup.md
```

Then remove only the empty directories and verify absence:

```bash
rmdir docs/superpowers/specs docs/superpowers/plans docs/superpowers
test ! -e docs/superpowers
```

Expected: `docs/superpowers` does not exist before any push or PR creation.

- [ ] **Step 4: Commit the approved temporary-doc removal**

```bash
git add -u docs/superpowers
git commit -m "chore(repo): remove temporary superpowers docs"
```

- [ ] **Step 5: Re-run the acceptance gate after deletion**

```bash
go test ./packages/eventindexer/indexer
go test ./packages/eventindexer/... -run '^$'
git diff --check
test ! -e docs/superpowers
git status --short
```

Expected: tests and compile checks pass, no superpowers directory exists, and the worktree is clean.

---

### Task 5: Push and open the draft pull request

**Files:**

- Create temporarily outside the repository: `/tmp/eventindexer-inbox-startup-pr-body.md`
- Verify no repository file under: `docs/superpowers/`

**Interfaces:**

- Consumes: clean branch `codex/fix-eventindexer-inbox-startup` and GitHub authentication.
- Produces: a draft pull request against `taikoxyz/taiko-mono:main` that closes issue #22076.

- [ ] **Step 1: Perform the final branch and diff review**

```bash
git status --short --branch
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
if git diff --name-only origin/main...HEAD | rg '^docs/superpowers/'; then exit 1; fi
```

Expected: the branch is clean, the diff contains only eventindexer production/tests/examples/README files, and no temporary docs appear.

- [ ] **Step 2: Run the required completion verification skill and checks**

Invoke `superpowers:verification-before-completion`, then re-run the commands it requires. At minimum, retain fresh passing evidence for:

```bash
go test ./packages/eventindexer/indexer
go test ./packages/eventindexer/... -run '^$'
git diff --check origin/main...HEAD
```

Expected: all commands exit zero immediately before pushing.

- [ ] **Step 3: Push the branch**

```bash
git push -u origin codex/fix-eventindexer-inbox-startup
```

Expected: GitHub accepts the branch and sets its upstream.

- [ ] **Step 4: Write the exact draft PR body outside the repository**

Use `apply_patch` to create `/tmp/eventindexer-inbox-startup-pr-body.md` with:

```markdown
## Summary

- restore the dedicated `SHASTA_INBOX_ADDRESS` configuration removed by #21697
- let L2 indexers start from their checkpoint or block zero without an L1 Inbox
- skip `activationTimestamp()` when sync can resume from an existing checkpoint
- validate L1 Inbox configuration before opening the database or RPC client

## Regression cause

#21697 intended to remove the legacy `l1TaikoAddress`, but the merged code kept
it as a required flag, removed `shastaInboxAddress`, and reused the retained
address as the Shasta Inbox binding. Startup then queried that L1 binding before
checking the layer or database checkpoint, which made L2 startup impossible and
made L1 startup depend on the wrong deployed address.

## Startup behavior

| Layer | Mode   | Checkpoint | Start              | Activation call |
| ----- | ------ | ---------- | ------------------ | --------------- |
| L1    | sync   | present    | latest - 1         | no              |
| L1    | sync   | absent     | first Shasta block | yes             |
| L1    | resync | ignored    | first Shasta block | yes             |
| L2    | sync   | present    | latest - 1         | no              |
| L2    | sync   | absent     | 0                  | no              |
| L2    | resync | ignored    | 0                  | no              |

Current charts already provide `SHASTA_INBOX_ADDRESS`, so this fix requires no
chart migration.

## Test plan

- `go test ./packages/eventindexer/indexer`
- `go test ./packages/eventindexer/... -run '^$'`
- `git diff --check origin/main...HEAD`

Fixes #22076
```

- [ ] **Step 5: Create and verify the draft PR**

```bash
gh pr create --draft --base main --head codex/fix-eventindexer-inbox-startup --title "fix(eventindexer): restore layer-aware inbox startup" --body-file /tmp/eventindexer-inbox-startup-pr-body.md
gh pr view --json number,url,isDraft,title,body,headRefName,baseRefName
```

Expected: `isDraft` is `true`, base is `main`, head is `codex/fix-eventindexer-inbox-startup`, the title matches, and the body includes `Fixes #22076`.

- [ ] **Step 6: Delete the temporary PR body**

Use `apply_patch` to delete `/tmp/eventindexer-inbox-startup-pr-body.md`. Confirm it was never added to the repository with:

```bash
git status --short
```

Expected: the worktree remains clean.
