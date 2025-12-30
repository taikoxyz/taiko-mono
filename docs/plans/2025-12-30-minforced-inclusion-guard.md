# MinForcedInclusionCount Guard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Guard Inbox config `minForcedInclusionCount` against values above `type(uint8).max` by validating in `LibInboxSetup.validateConfig` and covering it with a revert test in `InboxActivation.t.sol`.

**Architecture:** Extend config validation to add a dedicated error and require check on `minForcedInclusionCount`; add a Foundry test that builds a config exceeding `uint8` limits and asserts the revert selector when constructing `Inbox`. No other behavior changes.

**Tech Stack:** Solidity, Foundry.

### Task 1: Guard minForcedInclusionCount upper bound

**Files:**

- Modify: `packages/protocol/test/layer1/core/inbox/InboxActivation.t.sol`
- Modify: `packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol`

**Step 1: Write the failing test**

```solidity
function test_validateConfig_RevertWhen_MinForcedInclusionCountTooLarge() public {
    IInbox.Config memory cfg = _buildConfig();
    cfg.minForcedInclusionCount = uint256(type(uint8).max) + 1;

    vm.expectRevert(LibInboxSetup.MinForcedInclusionCountTooLarge.selector);
    new Inbox(cfg);
}
```

**Step 2: Run test to verify it fails**

Run: `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/core/inbox/InboxActivation.t.sol'`

Expected: FAIL because the revert selector is not emitted.

**Step 3: Write minimal implementation**

Add error and require in `LibInboxSetup.validateConfig`:

```solidity
error MinForcedInclusionCountTooLarge();

require(_config.minForcedInclusionCount <= type(uint8).max, MinForcedInclusionCountTooLarge());
```

**Step 4: Run test to verify it passes**

Run: `cd packages/protocol && FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/core/inbox/InboxActivation.t.sol'`

Expected: PASS.

**Step 5: Commit**

```bash
git add packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol \
        packages/protocol/test/layer1/core/inbox/InboxActivation.t.sol \
        docs/plans/2025-12-30-minforced-inclusion-guard.md
git commit -m "feat(protocol): guard minForcedInclusionCount"
```
