# Design Doc: Surface "Quota Exceeded" errors in the Bridge UI

Status: Draft / proposal (no implementation)
Owner: TBD
Package: `packages/bridge-ui`

## 1. Summary

When a user claims (processes) a bridge message whose value would push a token
over the bridge's per-period **quota**, the destination `Bridge.processMessage`
call reverts with the `QM_OUT_OF_QUOTA` error raised by the `QuotaManager`
contract. Today the Bridge UI does not recognize this condition: the claim
either fails with a generic "unknown error" toast, or the user is left
wondering why an otherwise-valid, fully-synced message will not go through.

This document proposes making quota exhaustion a **first-class, explained state**
in the UI: detect it both proactively (before the user pays gas to claim) and
reactively (when a claim reverts), and show a clear message telling the user
what happened and roughly when they can try again.

Reference transactions (both are `processMessage` claims that hit the quota
limit):

- L1: https://etherscan.io/tx/0x6e3aaa9b6000b20dcb84e7364557e7b6eca89de4df1ad424c4192b3011ce54e0
- L2: https://taikoscan.io/tx/0x18b7a9e412e5067a6e342e5c978fda06404b52fb3375e30096782a8fb274fc59

## 2. Background: how the quota works

The `QuotaManager` contract rate-limits the **value** that can be bridged per
token within a rolling window. Relevant surface (from the deployed ABI):

- `error QM_OUT_OF_QUOTA()` — thrown when a consume would exceed the available quota.
- `availableQuota(address _token, uint256 _leap) → uint256` — quota available
  now, optionally projected `_leap` seconds into the future.
- `tokenQuota(address token) → (uint48 updatedAt, uint104 quota, uint104 available)`
  — `quota` is the per-period cap (and the amount that refills each period);
  `available` is what remained as of `updatedAt`.
- `quotaPeriod() → uint24` — the refill window, in seconds.
- `consumeQuota(address _token, uint256 _amount)` — called by the Bridge during
  `processMessage`; reverts `QM_OUT_OF_QUOTA` when `_amount > availableQuota`.

Key properties:

- Quota is enforced on the **destination chain** (where funds are released). For
  an L2→L1 withdrawal the QuotaManager lives on L1; an L1→L2 route may or may not
  have one configured.
- Quota only applies to **value transfers**: ETH (token address = zero address)
  and ERC-20 (canonical token address). NFTs (ERC-721/1155) are **not**
  quota-checked. This mirrors the relayer, which skips quota for NFTs.
- Quota is a **shared, global** resource for a token/period — not per user. A
  large claim by someone else, or several concurrent claims, can exhaust it.
- Quota **refills linearly** over `quotaPeriod`. Roughly:
  `refillPerSecond = quota / quotaPeriod`.
- If a message's value exceeds `quota` (the full per-period cap), it can **never**
  clear in a single period — it is permanently blocked by quota until governance
  raises the cap. This edge case needs distinct messaging.

The relayer already models this in
`packages/relayer/processor/has_quota_available.go`: it calls
`AvailableQuota(token, 0)`, compares against the message value, and if short,
waits `quotaPeriod`. The UI logic should be consistent with that behavior, but
can present a more precise "retry after" estimate (see §5.3).

## 3. Current state in the Bridge UI

- No references to quota exist anywhere under `packages/bridge-ui/src`
  (no ABI, no config field, no error class, no i18n copy).
- Errors are enumerated in `src/libs/error/errors.ts` and routed to toasts in
  `src/libs/bridge/handleBridgeErrors.ts` (a `switch (true)` on `error instanceof …`).
  There is no `QM_OUT_OF_QUOTA` case, so it falls through to
  `bridge.errors.unknown_error`.
- The claim path is `Bridge.processMessage` →
  `processNewMessage` in `src/libs/bridge/Bridge.ts`. It estimates gas, then
  `simulateContract` + `writeContract`. A quota failure surfaces as a
  revert either at `estimateGas`/`simulateContract` (caught, currently falls
  back to a hardcoded gas limit and then reverts on-chain) or at send time.
- Pre-claim checks live in `src/components/Dialogs/Shared/ClaimPreCheck.svelte`
  (`checkConditions` runs a `Promise.allSettled` of prerequisite checks such as
  "enough ETH for gas"). This is the natural home for a proactive quota check.
- `isTransactionProcessable` (`src/libs/bridge/isTransactionProcessable.ts`)
  gates whether a tx is claimable at all; today it only checks block sync
  status. A quota-blocked message is "processable" per sync but will still
  revert — so quota must be a **separate, non-fatal** signal, not folded into
  this boolean.
- Routing addresses are typed by `AddressConfig` in `src/libs/bridge/types.ts`
  (`RoutingMap`). There is no `quotaManagerAddress` field yet.

## 4. Goals / non-goals

Goals:

1. Detect quota exhaustion **before** the user submits a claim, and block the
   claim button with an explanatory message + estimated retry time.
2. Detect quota exhaustion **after** a claim reverts (covers the race where
   quota drains between check and submit) and show a matching, helpful toast
   instead of "unknown error".
3. Distinguish "temporarily out of quota, retry in ~X" from "amount exceeds the
   maximum per-period limit and cannot be claimed until the cap changes".
4. Consistency with relayer semantics (ETH + ERC-20 only, destination-chain
   QuotaManager, NFTs exempt).

Non-goals:

- Changing quota mechanics or the contracts.
- Auto-retrying/queuing the claim when quota refills (could be a follow-up).
- Splitting a claim into smaller amounts.
- Quota display for NFT bridging.

## 5. Proposed design

### 5.1 Config & ABI plumbing

- Add optional `quotaManagerAddress?: Address` to `AddressConfig` in
  `src/libs/bridge/types.ts`. Populated per route in the generated/committed
  bridge config (only where a QuotaManager is deployed — typically the L1 side
  of L2→L1 routes). Absence ⇒ quota not enforced on that route ⇒ skip all quota
  logic.
- Add a minimal `quotaManagerAbi` under `src/abi/` exporting just
  `availableQuota`, `tokenQuota`, `quotaPeriod`, and the `QM_OUT_OF_QUOTA` error
  (the error entry is what lets viem decode reverts by name).

### 5.2 New error type

Add to `src/libs/error/errors.ts`:

```ts
export class QuotaExceededError extends Error {
  name = 'QuotaExceededError';
}
```

Export via `src/libs/error/index.ts`. Optionally carry structured context
(available, required, retryAfterSeconds, exceedsCap) on the instance so the
toast/inline UI can render specifics without re-fetching.

### 5.3 Quota helper module

New `src/libs/bridge/checkQuota.ts` (name TBD) exposing something like:

```ts
type QuotaStatus = {
  enabled: boolean; // false when no QuotaManager on this route or token is NFT
  hasQuota: boolean; // required <= available
  available: bigint;
  required: bigint;
  cap: bigint; // tokenQuota.quota — the per-period maximum
  exceedsCap: boolean; // required > cap → never claimable this period
  retryAfterSeconds: number; // 0 when hasQuota; else estimated seconds to refill
};

async function getQuotaStatus(bridgeTx): Promise<QuotaStatus>;
```

Logic:

1. Resolve `quotaManagerAddress` for `destChainId`/`srcChainId` from the routing
   map. If absent → `{ enabled: false, hasQuota: true }` (nothing to check).
2. Determine the quota token + amount from the message:
   - ETH transfer → token = zero address, amount = `message.value`.
   - ERC-20 → token = canonical token address, amount = bridged amount.
   - ERC-721/1155 → `{ enabled: false, hasQuota: true }` (exempt).
3. `available = availableQuota(token, 0n)` (mirror the relayer's `_leap = 0`).
4. `{ quota: cap } = tokenQuota(token)`; `period = quotaPeriod()`.
5. `hasQuota = amount <= available`.
6. `exceedsCap = amount > cap` (cap `0` typically means "no quota for this token"
   → treat as unlimited/enabled:false; confirm sentinel during implementation).
7. `retryAfterSeconds`: if `hasQuota` → 0; else if `exceedsCap` → `Infinity`
   (surface as "cannot be claimed until the limit is raised"); else
   `ceil((amount - available) * period / cap)`. This is a linear-refill estimate
   and strictly more informative than the relayer's coarse "wait one full
   period". Present it rounded (e.g. "~2h 15m") and framed as an estimate,
   because quota is shared and can drain again.

All reads are `readContract` calls against the **destination** chain client.

### 5.4 Proactive check (primary UX) — ClaimPreCheck

Extend `ClaimPreCheck.svelte`:

- Add `getQuotaStatus(tx)` to the `checkConditions` `Promise.allSettled` set.
- Track `quotaStatus` in component state. When `enabled && !hasQuota`, set a
  new blocking condition (parallel to `onlyDestOwnerCanClaimWarning`): render an
  `Alert` explaining quota exhaustion, and keep `canContinue = false` /
  `hideContinueButton` behavior so the user can't proceed to pay gas on a claim
  that will revert.
- Copy differentiates the two cases via `exceedsCap`:
  - temporary: "The bridge's hourly transfer limit for {symbol} is currently
    reached. You can claim this transfer in about {retryAfter}."
  - hard cap: "This transfer's amount exceeds the bridge's per-period limit for
    {symbol} and can't be claimed until the limit is increased. Please contact
    support."
- Because quota is global and time-varying, re-run the check on dialog open and
  optionally on a light interval/poll while the dialog is open (reuse existing
  polling utilities under `src/libs/polling`).

### 5.5 Reactive detection (safety net) — claim revert

In `Bridge.processMessage`'s `catch` (in `src/libs/bridge/Bridge.ts`) and/or in
`handleBridgeError`:

- Use viem to detect the decoded revert. With the QuotaManager error in an ABI,
  a `ContractFunctionRevertedError` / `BaseError.walk()` will expose
  `errorName === 'QM_OUT_OF_QUOTA'`. Also match the raw selector as a fallback.
- On match, throw/normalize to `QuotaExceededError` (optionally enriched by a
  follow-up `getQuotaStatus` read to compute `retryAfter`).
- Add a `case error instanceof QuotaExceededError` to `handleBridgeError` in
  `src/libs/bridge/handleBridgeErrors.ts` that shows a dedicated
  `warningToast` (not `errorToast` — it's an expected, transient condition)
  with title/message from i18n.

This reactive layer is essential because the proactive snapshot can be stale by
the time the transaction lands (someone else drains the quota first).

### 5.6 i18n

Add keys under `bridge.errors` and `transactions.claim` in
`src/i18n/en.json` (and siblings), e.g.:

- `bridge.errors.quota_exceeded.title`
- `bridge.errors.quota_exceeded.message` (temporary, supports `{retryAfter}`,`{symbol}`)
- `bridge.errors.quota_exceeded.exceeds_cap_message`
- `transactions.claim.steps.pre_check.quota_blocked` (inline Alert copy)

## 6. Edge cases

- **No QuotaManager on route** → skip entirely (`enabled: false`).
- **NFT bridging** → exempt; never show quota UI.
- **`amount > cap`** → permanent-until-governance; distinct copy, no retry timer.
- **Race: quota drains after pre-check passes** → caught by §5.5 reactive path.
- **Race: quota refills after pre-check fails** → poll while dialog open; user
  can retry; worst case they re-open the dialog.
- **RETRIABLE / retryMessage path** → quota is also consumed on retry; apply the
  same check/detection there, not only on the initial `NEW` claim.
- **`tokenQuota.quota == 0` sentinel** → confirm whether zero means "unlimited"
  vs "fully blocked" during implementation and branch accordingly (the relayer
  only ever calls `availableQuota`, so verify against the contract).
- **Relayer vs self-claim** → when the relayer is handling the message it will
  wait for quota; if the UI shows the tx as pending-relayer, prefer an
  informational note over a hard block. Manual/self-claim is where the blocking
  pre-check matters most.
- **uint104/uint48 ranges** → use `bigint` throughout; never `Number()` a quota
  value before comparison.

## 7. Testing plan

Unit (vitest, alongside existing `*.test.ts` in `src/libs/bridge`):

- `getQuotaStatus`: enabled=false when no manager / NFT; hasQuota true/false
  boundaries (`amount == available`, `± 1`); `exceedsCap`; `retryAfterSeconds`
  math; bigint safety. Mock `readContract`.
- Revert decoding: given a viem `QM_OUT_OF_QUOTA` error object, `handleBridgeError`
  produces the quota toast; given other reverts, it does not.

Component:

- `ClaimPreCheck.svelte`: blocks continue and renders the correct Alert variant
  for temporary vs hard-cap; unblocks when a poll shows quota restored.

Manual / testnet:

- Reproduce against a route with a low quota cap; confirm both the proactive
  block and the reactive toast, and that NFT claims are unaffected.

## 8. Rollout & risks

- Additive and gated on config: routes without `quotaManagerAddress` are
  unchanged, so risk is contained.
- Extra RPC reads per claim (3 small `readContract` calls) — negligible;
  can be memoized for the dialog's lifetime.
- Main correctness risk is the `quota == 0` sentinel and the `retryAfter`
  estimate; both are called out as implementation-time verifications.

## 9. Open questions

1. Confirm the `tokenQuota.quota == 0` semantics (unlimited vs blocked).
2. Do we want a follow-up that auto-enables claiming once quota refills (timer +
   re-check), or is a manual retry acceptable for v1?
3. Should the pre-check surface remaining quota proactively on the amount input
   during **bridging** (deposit/withdraw form), warning users before they even
   send, or only at claim time? (This doc scopes to claim time.)
4. Copy/support-link for the hard-cap case — owner: design/support.

## 10. Affected files (anticipated)

- `src/libs/bridge/types.ts` — add `quotaManagerAddress?` to `AddressConfig`.
- `src/abi/index.ts` (or new file) — add `quotaManagerAbi` incl. `QM_OUT_OF_QUOTA`.
- `src/libs/bridge/checkQuota.ts` — new `getQuotaStatus` helper (+ test).
- `src/libs/error/errors.ts` / `index.ts` — add `QuotaExceededError`.
- `src/libs/bridge/Bridge.ts` — normalize `QM_OUT_OF_QUOTA` reverts (claim + retry).
- `src/libs/bridge/handleBridgeErrors.ts` — add quota toast case.
- `src/components/Dialogs/Shared/ClaimPreCheck.svelte` — proactive block + Alert.
- `src/i18n/en.json` (+ locales) — new strings.
- Bridge config/address maps — populate `quotaManagerAddress` per route.
