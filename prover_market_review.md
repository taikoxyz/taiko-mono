# ProverMarket Review

## Scope

I reviewed the new prover-market path with the assumption that the intended goal is to make proving permissionless for Taiko without introducing a new privileged prover choke point.

Files read:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol`
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol`
- `packages/protocol/contracts/layer1/core/iface/IInbox.sol`
- `packages/protocol/contracts/layer1/core/iface/IProverMarket.sol`
- `packages/protocol/contracts/layer1/core/libs/LibBonds.sol`
- `packages/protocol/contracts/layer1/core/libs/LibInboxSetup.sol`
- `packages/protocol/contracts/layer1/core/libs/LibForcedInclusion.sol`
- `packages/protocol/contracts/layer1/core/libs/LibCodec.sol`
- `packages/protocol/contracts/layer1/core/libs/LibBlobs.sol`
- `packages/protocol/contracts/layer1/core/libs/LibHashOptimized.sol`
- `packages/protocol/contracts/shared/common/EssentialContract.sol`
- `packages/protocol/contracts/shared/libs/LibAddress.sol`
- `packages/protocol/contracts/shared/signal/SignalService.sol`
- `packages/protocol/contracts/layer1/core/iface/IProposerChecker.sol`
- `packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol`
- the full `packages/protocol/test/layer1/core/inbox` tree and its local mocks/helpers
- the pre-market `Inbox` implementation at the parent of commit `ac6e2d494` to compare against live Shasta behavior
- `packages/protocol/prover-market-design.md`

Validation run:
- `forge test --match-path 'test/layer1/core/inbox/*'` from `packages/protocol`
- Result: 108 tests passed

Working-tree status:
- Finding 3 has since been fixed locally by replacing the inline proposal-path ETH transfer with internal fee accrual to the recipient's withdrawable market balance.
- Findings 1, 2, and 4 remain open.

Review assumptions:
- Everything that existed before the ProverMarket change was already live in the Shasta fork, so regressions against the old `Inbox` liveness model matter.
- Every actor except the DAO may be malicious.
- A finding counts as serious if it lets a prover, proposer, or fee recipient extract value, force long proof delays, or halt proposal acceptance without DAO intervention.

## Finding 1: the market removes Shasta's live liveness-enforcement path, but does not replace it

Severity: Critical

The old live Shasta path still had a best-effort late-proof penalty in `Inbox.prove()`: once proving became permissionless, `_processLivenessBond` could debit the assigned party's bond and credit part of it to the actual prover. The new market path explicitly disables that old logic whenever `proverMarket != address(0)`, but `ProverMarket` does not implement a replacement slashing or timeout-settlement mechanism.

The regression is visible in two places:
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol:279-346` only calls `_proverMarket.beforeProofSubmission(...)` before proving and `_proverMarket.onProofAccepted(...)` after proving.
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:362-380` ignores `_caller`, `_actualProver`, `_firstNewProposalId`, and `_finalizedAt`; it only updates `lastFinalizedProposalId` and releases displaced bonds.

This is directly at odds with the design doc:
- `packages/protocol/prover-market-design.md:15-16` says the market should own "slashing state".
- `packages/protocol/prover-market-design.md:38-44` says the market is responsible for "tracking liability for slashing and exit".
- `packages/protocol/prover-market-design.md:146-149` says the prover is still obligated to prove because the "bond [is] at stake".
- `packages/protocol/prover-market-design.md:205-208` says the market owns bond accounting when enabled.

What the implementation actually does is pay the active epoch up front on proposal acceptance:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:321-326`

After that payment, there is no on-chain consequence for the active prover simply refusing to prove. The only fallback is the global permissionless window in `beforeProofSubmission`:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:345-358`

Attack path:
1. A prover bids low enough to become active.
2. Proposers keep depositing fee credit and continue proposing.
3. The market pays the active prover immediately for each accepted proposal.
4. The active prover stops proving.
5. Third parties can only rescue the chain after `permissionlessProvingDelay`, and they do so without any reward coming from the assigned prover.

Why this matters:
- The market is supposed to make proving permissionless, but the current implementation creates an exclusive proving window with no performance obligation.
- It is a regression from the already-live Shasta logic, not just a missing future enhancement.
- The flat `_minBond` is only a lockup, not an economic penalty. The attacker is risking temporary capital, not a slash proportional to the harm they cause.

Suggested direction:
- Reintroduce a late-proof settlement path when the market is enabled.
- Do not pay the prover irrevocably at proposal-accept time; escrow the fee and settle it based on whether the assigned prover actually proves before the timeout.
- Make `onProofAccepted` use the timing and attribution fields it currently ignores.

## Finding 2: a zero-fee winner can become permanently irreplaceable, and `exit()` does not actually stop future assignments

Severity: Critical

The auction rule is a strict undercut:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:197-200`

There is no lower bound on `_feeInGwei`, so `0` is a valid winning fee. Once an active epoch is at `0`, nobody can outbid it.

At the same time, `exit()` does not remove the active epoch from future assignment. It only flips a global flag:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:235-258`

If there is no pending replacement, `onProposalAccepted()` still keeps `state.activeEpochId` unchanged and still assigns the next proposal to that same exiting epoch:
- transition logic: `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:275-313`
- assignment logic: `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:315-330`

This violates the design intent in `packages/protocol/prover-market-design.md:120-128`, which says the exiting operator should stay liable for already-assigned proposals. The implementation keeps assigning new proposals as well.

Attack path:
1. A malicious prover bids `0`.
2. The prover becomes active.
3. The prover stops proving, or calls `exit()`.
4. No one can create a lower-fee pending epoch, so there is no replacement path through bidding.
5. New proposals remain exclusively assigned to the same epoch until each proposal individually ages past `permissionlessProvingDelay`.

Impact:
- The proving market becomes DAO-dependent again: the only practical recovery is `forcePermissionlessMode(true)`.
- The system can be pinned to the full permissionless delay for every proposal.
- This is especially bad because Finding 1 means the stuck operator is not slashed for causing the delay.

Suggested direction:
- Disallow `feeInGwei == 0`, or introduce a replacement rule that does not require a strictly lower fee once the floor is reached.
- If `activeEpochExiting == true` and there is no pending replacement, stop assigning new proposals to the exiting epoch and fall back to immediate permissionless proving for newly accepted proposals.

## Finding 3: proposal-time fee payment breaks CEI inside the market and gives the active prover both a revert-based DoS and a reentrancy surface

Severity: High

`Inbox.propose()` is on the proposal critical path and calls the market hook synchronously:
- `packages/protocol/contracts/layer1/core/impl/Inbox.sol:220-223`

Inside `onProposalAccepted()`, the market sends ETH to an arbitrary `feeRecipient` before persisting `marketState = state`:
- fee transfer: `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:321-326`
- delayed state write: `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:330`

The ETH helper forwards all remaining gas:
- `packages/protocol/contracts/shared/libs/LibAddress.sol:52-61`

Neither `onProposalAccepted()` nor `bid()` nor `exit()` is protected by the market's reentrancy guard.

This creates two separate problems.

First, revert-based DoS:
- If the active prover points `feeRecipient` at a contract that rejects ETH, every proposal from a proposer with sufficient fee credit will revert in `onProposalAccepted()`.
- Because the hook is inside `Inbox.propose()`, this blocks proposal acceptance itself, not just fee settlement.

The important nuance is that this path is gated by `feeCreditBalances[_proposer] >= feeWei` at
`packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:323-325`, so it does not literally
block every mathematically possible proposal. It does, however, block the normal fee-bearing path
that the market is designed around, and the attacker only needs to lock `_minBond` to set it up.

Second, stale-state reentrancy:
- `onProposalAccepted()` works on a memory copy of `marketState`.
- A malicious `feeRecipient` can reenter `bid()` or `exit()` before `marketState` is written back.
- The reentrant call sees the old active/pending epoch layout and can mutate accounting against stale state.

One concrete bad path:
1. There is an active epoch and a pending epoch waiting to activate.
2. `onProposalAccepted()` starts activating the pending epoch, but has not written `marketState` yet.
3. The newly active prover's fee-recipient fallback reenters `bid()`.
4. `bid()` still sees the old `pendingEpochId`, refunds that pending epoch's bond, and creates a new pending epoch based on stale state.
5. When control returns, the outer `onProposalAccepted()` overwrites `marketState` with its old memory copy, losing the reentrant pending pointer and corrupting the intended bond/epoch invariants.

Even without a profit path, this is enough to break market accounting and make proposal liveness depend on prover-controlled fallback behavior.

Suggested direction:
- Do not push ETH inside `onProposalAccepted()`. Accrue a receivable for the fee recipient and let them pull it later.
- If a push model is kept, persist all state before the external call and protect `onProposalAccepted()`, `bid()`, and `exit()` with the same reentrancy lock.

## Finding 4: the fixed 8-slot displaced-epoch queue gives adversaries a direct proposal-halt lever

Severity: High

Displaced epochs are stored in a bounded array:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:80-82`

Every time a pending epoch replaces the active epoch, `onProposalAccepted()` pushes the previous active epoch into that array:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:278-303`

Once 8 displaced epochs are waiting, `_addDisplacedEpoch()` reverts:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:405-410`

Those displaced epochs are only released when enough proposals have been finalized:
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:377-380`
- `packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:413-429`

That means proposal liveness now depends on bidder churn never outrunning proof finalization. Under the stated threat model, that is not a safe assumption.

Attack path:
1. An attacker (or small cartel) seeds an initial active epoch with a fee like `10`.
2. Before proofs catch up, they keep submitting lower bids `9, 8, 7, ...`.
3. Each new accepted proposal activates the next pending epoch and displaces the old active epoch.
4. After eight such replacements, the next `onProposalAccepted()` reverts with `TooManyDisplacedEpochs()`.
5. Because that revert happens inside `Inbox.propose()`, proposal acceptance halts.

This does not require a large coalition. A single operator can self-churn through multiple epochs if they pre-fund enough bond.

`forcePermissionlessMode(true)` does not solve this by itself. In
`packages/protocol/contracts/layer1/core/impl/ProverMarket.sol:275-281`, `permissionlessMode`
only makes `needsTransition` true; if a pending epoch still exists, the code still calls
`_addDisplacedEpoch(state.activeEpochId)`. So the overflow remains reachable even while proving is
otherwise forced permissionless.

Suggested direction:
- Remove the hard 8-epoch cap, or at least make the overflow behavior degrade to permissionless mode instead of reverting.
- If the cap is intentional for gas reasons, the contract needs a proof that churn cannot exceed release under malicious timing. The current design does not have that proof, especially after Finding 1 removes strong incentives to finalize quickly.

## Test coverage gaps

The existing `packages/protocol/test/layer1/core/inbox/ProverMarket.t.sol` suite is mostly happy-path and single-step transition coverage. It does not cover the adversarial cases above.

Missing tests I would consider mandatory before shipping:
- active fee `0` followed by no-progress / no-replacement behavior
- `exit()` on the active epoch when there is no pending replacement
- malicious `feeRecipient` that reverts on ETH receipt
- malicious `feeRecipient` that reenters `bid()` or `exit()` during `onProposalAccepted()`
- repeated active-epoch churn until displaced-epoch capacity is exceeded
- late proof settlement behavior when the assigned epoch never proves

## Bottom line

The current implementation does not yet achieve the stated goal of permissionless proving safely. It replaces the old live Shasta liveness model with a market that controls exclusivity and payments, but not accountability. In the current form, a malicious prover can cheaply lock up exclusivity, delay proofs until the global fallback, and in some cases halt proposal acceptance outright.
