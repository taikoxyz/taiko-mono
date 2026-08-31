# PROPOSAL-0023: Upgrade the L1 and L2 Bridges for the EIP-8037 Ether Send Cap

## Executive Summary

[PR #22077](https://github.com/taikoxyz/taiko-mono/pull/22077) raised `Bridge._SEND_ETHER_GAS_LIMIT`
from 35,000 to 135,000 gas. That constant is the `CALL` gas operand the bridge uses whenever it
sends Ether to a message recipient. EIP-8037 (state-creation repricing, scheduled for Glamsterdam)
charges 64 state bytes × 1,530 gas/byte = 97,920 gas to create one fresh storage slot. In any
realistic claim transaction — one that does not buy gas beyond the 16.7M per-transaction execution
cap, and so has an empty state-gas reservoir — that charge is deducted from the callee frame's own
gas. A smart wallet that writes a single fresh slot on its receive path would therefore run out of
gas under the old 35,000 cap, and because a failed Ether send reverts message processing, that
wallet's inbound messages would become permanently unclaimable. The new cap is the legacy 35,000
callee budget plus one slot-creation charge, rounded up: 35,000 + 97,920 = 132,920 → 135,000. Wallets
that fit before the fork still fit after it, as long as their receive path creates at most one
storage slot.

The constant is compiled into the bridge implementation, so the fix reaches production only when
both bridge proxies are pointed at a new implementation. **Proposal0023 is that bundle, and nothing
else.** No contract source changes ship with this proposal — #22077, #22058 (transient-storage
unification) and #22059 (gas-schedule docs) are all already on `main`.

On **L1** the complete behavioural delta between the live implementation and the one this proposal
deploys is that single line. Diffing the implementation's whole dependency tree from Proposal0017's
commit `b73608696` to `main` (`contracts/shared/{bridge,common,libs}` plus `ISignalService`) turns
up three changed files: `Bridge.sol`, `EssentialContract.sol` and `LibNames.sol`. `LibNames` only
gained an unused `B_PRECONF_SLASHER` constant, and the other two carry the transient-storage
refactor — which reuses the exact slot constants the live implementation already uses — plus the
cap.

On **L2** the leg is not a like-for-like redeploy. The L2 bridge still runs the protocol 1.10.0
implementation from October 2024, which predates the resolver refactor, so it additionally needs a
resolver that speaks the modern `IResolver` interface. [Why L2 Needs a New Resolver](#why-l2-needs-a-new-resolver)
covers that.

The proposal executes **2 top-level L1 actions** and **3 L2 actions**.

## Scope

Four contracts are deployed ahead of the vote — two `Bridge` implementations, plus a
`DefaultResolver` implementation and its `ERC1967Proxy` on L2. The proposal then re-points two proxies
and populates the new resolver:

| Chain | Contract                                                  | Change                                      |
| ----- | --------------------------------------------------------- | ------------------------------------------- |
| L1    | Bridge proxy `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | implementation → `<BRIDGE_NEW_IMPL_L1>`     |
| L2    | Bridge proxy `0x1670000000000000000000000000000000000001` | implementation → `<BRIDGE_NEW_IMPL_L2>`     |
| L2    | New `DefaultResolver` proxy `<L2_SHARED_RESOLVER>`        | `bridge` registered for chains 1 and 167000 |

Explicitly **not** touched by this proposal:

- **The L2 vaults** — `ERC20Vault` `0x1670000000000000000000000000000000000002`, `ERC721Vault`
  `0x1670000000000000000000000000000000000003`, `ERC1155Vault`
  `0x1670000000000000000000000000000000000004`. They are also on 1.10.0 implementations and keep
  resolving through the legacy registry.
- **The legacy L2 `AddressManager` `0x1670000000000000000000000000000000000006`.** It is neither
  migrated nor retired nor modified; it keeps serving the vaults exactly as it does today.
- **`Bridge.sol` itself, and the gas constants.** Those changed in #22077, which is already merged.
  This proposal only ships the already-merged code to the two proxies.
- **The L1 resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`.** The L1 leg reuses it unchanged;
  only L2 gets a new resolver.
- **Ownership.** No `transferOwnership`, no `acceptOwnership`, no initializer call on any live
  contract. The new L2 resolver is initialised with the DelegateController as owner at deploy time,
  before the proposal runs.
- **Hoodi and every other network.** This proposal targets mainnet governance only.

## Current State

Verified on-chain 2026-08-31.

|     | proxy                                        | owner                                                                                | live impl                                    | impl provenance                               |
| --- | -------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- | --------------------------------------------- |
| L1  | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0x1c94D798CFA08F396E5BA9F81697289c53273381` | Proposal0017, 2026-06-29, commit `b73608696`  |
| L2  | `0x1670000000000000000000000000000000000001` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83` | protocol 1.10.0, 2024-10-31, commit `9345f14` |

**The live L1 implementation is a `MainnetBridge`, not a `Bridge`.** `MainnetBridge` was the L1-only
subclass that #22058 deleted; this proposal deploys the unified shared `Bridge`. Reviewers diffing
"the live implementation" against `Bridge.sol` should expect that type change, and block explorers
will show a different contract name once the new implementation is verified. It is not a
behavioural change: `MainnetBridge` existed only to override the reentrancy lock and the call
context onto transient storage, and #22058 folded both mechanisms into `Bridge` at **byte-identical
slot constants** —

|                 | `MainnetBridge` / `LibFasterReentryLock` | `Bridge` on `main` |
| --------------- | ---------------------------------------- | ------------------ |
| call context    | `_CTX_SLOT = 0xe4ece821…dbadc2b9`        | identical          |
| reentrancy lock | `_REENTRY_SLOT = 0xa5054f72…31d9721b`    | identical          |

— so the claim that the only behavioural delta on L1 is the send cap still holds. Storage layout is
unchanged.

The generation gap between the two chains shows up in what each live implementation answers:

- The L1 implementation answers `resolver()` → `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`;
  `addressManager()` reverts.
- The L2 implementation answers `addressManager()` → `0x1670000000000000000000000000000000000006`;
  `resolver()`, `signalService()`, `quotaManager()` and `pauser()` **all revert**. That is the
  1.10.0 signature: those four are immutables that did not exist yet.

The four L1 immutables on the live proxy, which the new L1 implementation must reproduce exactly:

| Immutable         | Value                                        | `LibL1Addrs` constant                          |
| ----------------- | -------------------------------------------- | ---------------------------------------------- |
| `resolver()`      | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `SHARED_RESOLVER`                              |
| `signalService()` | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `SIGNAL_SERVICE`                               |
| `quotaManager()`  | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `QUOTA_MANAGER`                                |
| `pauser()`        | `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` | `MULTISIG_ADMIN_TAIKO_ETH` (`admin.taiko.eth`) |

The new L2 implementation instead takes the newly deployed resolver, `SIGNAL_SERVICE`
`0x1670000000000000000000000000000000000005`, and **zero** for both `quotaManager` and `pauser`.
Zero preserves today's behaviour rather than removing anything: `quota_manager@167000`,
`chain_watchdog@167000` and `bridge_watchdog@167000` are all unset on the legacy L2 registry, so L2
has no Ether quota today and only the owner can pause. The 1.10.0 `Bridge` has no `receive()` at
all, so the new pauser-only `receive()` is strictly more permissive than the status quo, not less.

Other live values a reviewer will want:

- L2 bridge balance ≈ **999,998,918.6 ETH**. This is the L2 premint float and it is what the L2 leg
  puts at risk; it moves with bridge traffic, so re-read it at execution time rather than trusting
  the digits here.
- L2 bridge `nextMessageId()` = `10101`, `paused()` = `false`.
- `DelegateController.lastExecutionId()` = `1`.

## Why L2 Needs a New Resolver

`Bridge` on `main` looks up `LibNames.B_BRIDGE` through `IResolver.resolve(uint256,bytes32,bool)`
(selector `0x6c6563f6`) at exactly three call sites — `Bridge.sol:491` (`isDestChainEnabled`),
`Bridge.sol:607` (`_proveSignalReceived`) and `Bridge.sol:658` (`_isSignalReceived`).

- The L1 resolver `0x8Efa0156…` is a modern `DefaultResolver`. `resolve(167000, "bridge", true)`
  returns `0x1670000000000000000000000000000000000001`.
- The L2 registry `0x1670000000000000000000000000000000000006` is the 1.10.0 `AddressManager`.
  `resolve(uint256,bytes32,bool)` **reverts** — the selector does not exist on it. Only
  `getAddress(uint64,bytes32)` works, returning `bridge@1 = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`
  and `bridge@167000 = 0x1670000000000000000000000000000000000001`.

Pointing the new implementation at `0x1670…0006` would therefore revert every `sendMessage` and
every `processMessage` on L2. L2 needs a registry that answers the modern selector.

The fix mirrors what L1 already did. Rather than migrating the legacy registry, L1 deployed a
separate `shared_resolver` in May 2025 and moved onto it only the contracts that received new
implementations (bridge, `erc20_vault`). The L1 NFT vaults still resolve through the legacy
`shared_address_manager` today. Proposal0023 replays that split on L2: a new `DefaultResolver` serves
the new bridge, the untouched L2 vaults keep using `0x1670…0006`, and only the names the bridge
actually reads are registered.

### Which registration is load-bearing

**The chain-1 entry is the one the bridge reads. The chain-167000 entry is not.** All three call
sites above use the explicit-`_chainId` overload of `resolve`, never the `block.chainid` overload at
`EssentialResolverContract.sol:77-79`. Every bridge operation that reaches them passes the
_counterparty_ chain id, because a same-chain check runs first in each case:

| Caller              | Reaches a lookup at | Chain id passed        | Same-chain check                                              |
| ------------------- | ------------------- | ---------------------- | ------------------------------------------------------------- |
| `sendMessage`       | `Bridge.sol:207`    | `_message.destChainId` | `diffChain(_message.destChainId)` at `:195`                   |
| `recallMessage`     | `Bridge.sol:246`    | `_message.destChainId` | `diffChain(_message.destChainId)` at `:235`                   |
| `processMessage`    | `Bridge.sol:311`    | `_message.srcChainId`  | `srcChainId == block.chainid` reverts at `:292`               |
| `isMessageFailed`   | `Bridge.sol:451`    | `_message.destChainId` | returns `false` unless `srcChainId == block.chainid`, `:449`  |
| `isMessageReceived` | `Bridge.sol:473`    | `_message.srcChainId`  | returns `false` unless `destChainId == block.chainid`, `:472` |

On the L2 bridge the counterparty is chain 1, so the chain-1 entry is what the new implementation
resolves on every send, every recall and every claim.

The chain-167000 entry is registered anyway, for two reasons: symmetry with the L1 resolver, which
carries both; and future consumers reached through the `block.chainid` overload, such as the vaults'
`onlyFromNamed(LibNames.B_BRIDGE)` at `BaseVault.sol:56` — which today resolves through the legacy
registry, but would need this entry if a vault were ever moved onto the new resolver. It is not
required for the bridge to function, and it is not dead weight either. Registering it now costs one
action and removes a future footgun.

## Upgrade Safety

### Storage layout

Slot boundaries are identical between the 1.10.0 lineage and `main`:

| slot    | 1.10.0                                                                                        | `main`                               |
| ------- | --------------------------------------------------------------------------------------------- | ------------------------------------ |
| 151     | `AddressResolver.addressManager`                                                              | `__gapFromOldAddressResolver[0]`     |
| 152–200 | `AddressResolver.__gap[49]`                                                                   | `__gapFromOldAddressResolver[1..49]` |
| 201.0   | `__reentry`                                                                                   | `__reentry`                          |
| 201.1   | `__paused`                                                                                    | `__paused`                           |
| 201.2   | `lastUnpausedAt` (uint64)                                                                     | unused                               |
| 202–250 | `__gap[49]`                                                                                   | `__gap[49]`                          |
| 251–300 | `__reserved1`/`nextMessageId`/`messageStatus`/`__ctx`/`__reserved2`/`__reserved3`/`__gap[44]` | identical                            |

`lastUnpausedAt` was dropped from `EssentialContract`, leaving stale bytes in slot 201 that nothing
reads. `addressManager` is absorbed by the gap that exists for exactly this reason — which is why
the live L2 proxy still answers `addressManager()` with `0x1670…0006`.

The decisive precedent: **the L1 bridge already made this exact jump.** It went from the same 1.10.0
implementation lineage (commit `9345f14`) straight to `0x1c94D798…` in Proposal0017 on 2026-06-29.
L2 is the same migration, two months later.

### The L2 bridge upgrades itself mid-call

The L2 bridge proxy is owned by the DelegateController, which is only reachable through a bridged
message that the L2 bridge itself processes. So `upgradeTo` on the L2 bridge necessarily executes
**inside the bridge's own `processMessage` frame**, while that frame's reentrancy lock is held. Each
step of that was checked:

1. `_authorizeUpgrade` is `onlyOwner` with **no** `nonReentrant` in both the 1.10.0 and the `main`
   `EssentialContract`, so the active reentrancy lock does not block `upgradeTo`.
2. `DelegateController.onMessageInvocation` reads `IBridge(msg.sender).context()` **before**
   `_executeActions`, so the context check runs against the old implementation's storage context,
   which is populated at that point.
3. After the swap, the new implementation reads the reentrancy lock from transient storage. A fresh
   transient slot reads `0`, and `_checkReentrancy()` only rejects `_TRUE` (2), so the next
   transaction passes. The stale storage `__reentry = _FALSE` the old implementation leaves behind
   is never read again.
4. The old implementation's frame continues after the swap using already-resolved delegatecall code.
   Its remaining writes — `messageStatus` (slot 252), the context slots (253–254), the `nonReentrant`
   epilogue on slot 201 — all land on slots the new layout agrees with, and it makes no external call
   back into the proxy. The governance message carries `value: 0` and `fee: 0`, so there is no refund
   path either.

This is the part of the proposal that carries real risk, and it is the part the
[fork rehearsal](#fork-rehearsal) was written to exercise against live mainnet state.

### EVM version

`foundry.toml` pins `evm_version = "osaka"` for both `profile.layer2` and `profile.shared`, so
`TSTORE`/`TLOAD` are available on L2.

## Action Order

### L1 — 2 top-level actions

1. `upgradeTo(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, <BRIDGE_NEW_IMPL_L1>)` — point the mainnet
   bridge at the implementation carrying the EIP-8037 send cap.
2. `sendMessage(...)` on `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` — carries the L2 batch below to
   the DelegateController. This action is **not written in `Proposal0023.s.sol`**;
   `BuildProposal._buildAllActions()` appends it automatically whenever `buildL2Actions()` returns a
   non-empty array. It carries `value: 0`, zero fee, `gasLimit = 5_000_000`,
   `srcOwner = 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (the DAO controller),
   `to = 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` (the DelegateController) and
   `destOwner = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA` (`PERMISSIONLESS_EXECUTOR`, so anyone
   can relay it on L2).

Note that `_buildAllActions()` appends the `sendMessage` **after** the `upgradeTo` on the same proxy,
so the L2 message is sent through the just-upgraded L1 bridge. That is safe — `upgradeTo` touches no
reentrancy lock, and with `value: 0` and zero fee the send cap is never reached — but it does mean
the new implementation's `sendMessage` runs `isDestChainEnabled(167000)` against its own immutable
resolver in the same transaction it goes live. See [Deployment](#deployment) for the dry run that
proves this before the vote.

### L2 — 3 actions, `l2ExecutionId = 0`, `l2GasLimit = 5_000_000`

Numbered here from 1; in `Proposal0023.s.sol` these are `actions[0]`, `actions[1]` and `actions[2]`.

1. (`actions[0]`) `<L2_SHARED_RESOLVER>.registerAddress(1, LibNames.B_BRIDGE, 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC)`
   — the entry the new implementation actually reads.
2. (`actions[1]`) `<L2_SHARED_RESOLVER>.registerAddress(167000, LibNames.B_BRIDGE, 0x1670000000000000000000000000000000000001)`
   — registered for symmetry and future consumers; the bridge itself never reads it.
3. (`actions[2]`) `upgradeTo(0x1670000000000000000000000000000000000001, <BRIDGE_NEW_IMPL_L2>)` — the
   mid-call self-upgrade described above.

`registerAddress` is encoded with `LibNames.B_BRIDGE` (`bytes32("bridge")`), not a hand-written
literal.

**On the ordering.** All three L2 actions execute in a **single transaction**:
`DelegateController.onMessageInvocation` calls `_executeActions` once, and
`Controller._executeActions` (`contracts/shared/governance/Controller.sol:58-64`) loops the whole
array in one frame. `upgradeTo` reads no name from the resolver, so an upgrade-first ordering would
revert nothing and would leave exactly the same end state — there is no window inside the batch in
which an outside caller could reach the new implementation against an empty registry. The
register-then-upgrade order shipped here is the correct, defensive choice, not a correctness
requirement.

The hazard the ordering is defending against is a different one: **the registrations must not land in
a later transaction or a later proposal.** If the upgrade shipped alone and the registrations
followed separately, then between the two the L2 bridge would be live with an implementation reading
an empty resolver, and every `sendMessage` and `processMessage` on L2 would revert until the second
transaction landed. Keeping all three in one message is what closes that window. Reviewers should
check that the three L2 actions are present in the same bundle, not that they appear in a particular
sequence within it.

### Parameter choices

- **`l2ExecutionId = 0`**, matching Proposal0007 and Proposal0011. `DelegateController` accepts
  `executionId == 0` as "unordered" or `executionId == ++lastExecutionId` as ordered.
  `lastExecutionId()` is currently `1`, so the ordered value would be `2` — which adds replay and
  ordering protection but breaks if any other L2 proposal executes first. Zero is the conventional
  choice here.
- **`l2GasLimit = 5_000_000`**, matching Proposal0011, which also bundled proxy upgrades. The three
  actions need roughly 100k. `Bridge.GAS_RESERVE` (800,000) is deducted from the limit before
  invocation, so the usable budget is comfortably above what the batch needs.
- **Resolver ownership.** The resolver is initialised with `DELEGATE_CONTROLLER` as owner at deploy
  time, and the two `registerAddress` calls are proposal actions so they are auditable in the DAO
  calldata. The alternative — registering at deploy time and then handing ownership over — would
  need an extra `acceptOwnership` action, because `EssentialContract` is `Ownable2Step`.

## Deployment

Run both deployments **before** the proposal is created; their output fills in the three placeholder
constants in `Proposal0023.s.sol`.

```bash
# Ethereum mainnet
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployBridgeUpgradeL1.s.sol:DeployBridgeUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast
```

```bash
# Taiko Alethia
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/mainnet/DeployBridgeUpgradeL2.s.sol:DeployBridgeUpgradeL2 \
  --rpc-url https://rpc.mainnet.taiko.xyz --broadcast
```

Both scripts deploy only. Neither upgrades a proxy nor calls an initializer on a live contract.
`DeployBridgeUpgradeL1` logs `BRIDGE_NEW_IMPL_L1`; `DeployBridgeUpgradeL2` logs
`L2_SHARED_RESOLVER`, its implementation, and `BRIDGE_NEW_IMPL_L2`. That is **four** contracts
across the two chains: one on L1, three on L2.

Verify all four on the block explorers before the proposal is created, so a delegate can read the
source behind each address rather than trusting the deployer. Use the same compiler settings the
branch pins (`solc 0.8.30`, `optimizer_runs = 200`; `evm_version = "osaka"` for the L2 profile) and
the constructor arguments the scripts pass. Explorer verification and the `forge verify-bytecode`
commands in the pre-execution checklist are two independent routes to the same assurance; run both,
since the explorer is the one a delegate can check without a local toolchain. Note that the L1 implementation will show as
`Bridge`, not `MainnetBridge` — see Current State for why that rename is expected.

Then, in the fill-in commit:

1. Set `BRIDGE_NEW_IMPL_L1`, `BRIDGE_NEW_IMPL_L2` and `L2_SHARED_RESOLVER` in `Proposal0023.s.sol`
   from the logged addresses.
2. **Replace — do not delete — `test_placeholderConstantsStillGuardTheBuilders`** in
   `test/layer1/proposals/Proposal0023.t.sol`. While the constants are zero, that test is what
   proves the no-argument builders forward them at all. Once they are real, it must become tests
   that assert the no-argument overloads forward the real constants **in the correct argument
   order** — both `buildL2Actions` parameters are `address`, so a transposed pair compiles silently
   and nothing else in the suite catches it. `test_buildL1Actions_UsesDeployedImplementations` in
   `Proposal0017.t.sol` is the precedent. Deleting the test instead leaves the no-argument path with
   no coverage at all.
3. Regenerate the calldata and dry-run the bundle:

```bash
cd packages/protocol
P=0023 pnpm proposal            # writes Proposal0023.action.md
P=0023 pnpm proposal:dryrun:l1
```

The dryrun should revert with `DryrunSucceeded()` — that is the success signal, not a failure.

The L1 dry run matters more than usual here. Because `_buildAllActions()` appends the `sendMessage`
after the `upgradeTo` on the same proxy, the dry run is what proves the just-upgraded implementation
can actually send: its `sendMessage` calls `isDestChainEnabled(167000)` against its own immutable
resolver, the L1 `SHARED_RESOLVER` `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`. That resolver does
carry the entry — `resolve(167000, "bridge", true)` returns
`0x1670000000000000000000000000000000000001` — so it passes, but the dry run is what demonstrates it
against live state before the vote rather than after it.

`P=0023 pnpm proposal:dryrun:l2` is also worth running: it asserts the DelegateController's
preconditions (self-owned, `l2Bridge()` = the L2 bridge, `daoController()` = the L1 DAO controller)
and then executes the three L2 actions. Note what it does **not** cover — it calls
`DelegateController.dryrun` directly rather than delivering the batch through `processMessage`, so it
does not exercise the mid-call self-upgrade. Only the [fork rehearsal](#fork-rehearsal) does that.

The generated `Proposal0023.action.md` should be formatted with the repo formatter (the pre-commit
hook does this automatically), or reviewers should compare only the calldata line. A second reviewer
should re-run `P=0023 pnpm proposal` independently and diff the result.

## Verification

### Before execution

Substitute the deployed addresses. Every commented value is the expected result.

```bash
# L1 implementation immutables — all four must match the live proxy.
cast call <BRIDGE_NEW_IMPL_L1> "resolver()(address)"      --rpc-url <L1_RPC>  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call <BRIDGE_NEW_IMPL_L1> "signalService()(address)" --rpc-url <L1_RPC>  # 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C
cast call <BRIDGE_NEW_IMPL_L1> "quotaManager()(address)"  --rpc-url <L1_RPC>  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call <BRIDGE_NEW_IMPL_L1> "pauser()(address)"        --rpc-url <L1_RPC>  # 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F

# L2 resolver and implementation.
cast call <L2_SHARED_RESOLVER> "owner()(address)"         --rpc-url https://rpc.mainnet.taiko.xyz  # 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C
cast call <BRIDGE_NEW_IMPL_L2> "resolver()(address)"      --rpc-url https://rpc.mainnet.taiko.xyz  # <L2_SHARED_RESOLVER>
cast call <BRIDGE_NEW_IMPL_L2> "signalService()(address)" --rpc-url https://rpc.mainnet.taiko.xyz  # 0x1670000000000000000000000000000000000005
cast call <BRIDGE_NEW_IMPL_L2> "quotaManager()(address)"  --rpc-url https://rpc.mainnet.taiko.xyz  # 0x0000000000000000000000000000000000000000
cast call <BRIDGE_NEW_IMPL_L2> "pauser()(address)"        --rpc-url https://rpc.mainnet.taiko.xyz  # 0x0000000000000000000000000000000000000000

# Both must be non-zero.
cast codesize <BRIDGE_NEW_IMPL_L1> --rpc-url <L1_RPC>
cast codesize <BRIDGE_NEW_IMPL_L2> --rpc-url https://rpc.mainnet.taiko.xyz

# The resolver is a proxy, and L2 actions 0-1 make the DAO call registerAddress on it. owner()
# says who controls it, not what code runs. Pin the implementation it delegates to: must equal the
# address DeployBridgeUpgradeL2 logged as `resolver impl`, left-padded to 32 bytes.
cast storage <L2_SHARED_RESOLVER> \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url https://rpc.mainnet.taiko.xyz

# Authenticate the code itself, not just its getters, for all four deployed contracts. A
# substituted contract can answer every getter above while carrying different logic, and these
# implementations become the logic of proxies holding roughly 1,000,000 ETH.
forge verify-bytecode <BRIDGE_NEW_IMPL_L1> Bridge --rpc-url <L1_RPC> \
  --constructor-args $(cast abi-encode "c(address,address,address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C \
    0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F)

forge verify-bytecode <BRIDGE_NEW_IMPL_L2> Bridge --rpc-url https://rpc.mainnet.taiko.xyz \
  --constructor-args $(cast abi-encode "c(address,address,address,address)" \
    <L2_SHARED_RESOLVER> 0x1670000000000000000000000000000000000005 \
    0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000)

forge verify-bytecode <L2_RESOLVER_IMPL> DefaultResolver --rpc-url https://rpc.mainnet.taiko.xyz

forge verify-bytecode <L2_SHARED_RESOLVER> ERC1967Proxy --rpc-url https://rpc.mainnet.taiko.xyz \
  --constructor-args $(cast abi-encode "c(address,bytes)" <L2_RESOLVER_IMPL> \
    $(cast calldata "init(address)" 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C))
```

In the second command, the first constructor argument is `<L2_SHARED_RESOLVER>` — the proxy, not
the implementation. `DeployBridgeUpgradeL2` passes the proxy address to the `Bridge` constructor.

**Do not substitute a `cast codehash` comparison for this.** Hashing the runtime looks like the
obvious check and does not work here: `Bridge` carries **five** immutables at **25** patch sites —
`__resolver`, `signalService`, `quotaManager`, `pauser`, and OpenZeppelin `UUPSUpgradeable`'s
`__self = address(this)`. Because `__self` is the contract's own address, **two byte-identical
deployments at different addresses have different runtime hashes**, so no expected hash can be
published in advance or reproduced independently. Nor does
`keccak256(forge inspect Bridge deployedBytecode)` match a live deployment: the artifact carries
those 25 sites zero-filled. Both facts were measured on this branch on 2026-08-31 — artifact and
locally deployed runtime are each 14,913 bytes and differ in exactly those 25 regions, one group of
which is the deployer-dependent `__self`. `forge verify-bytecode` is immutable-aware and is what
handles this correctly; explorer verification (below) is the human-checkable equivalent.

**These checks are not redundant with the deploy scripts' own assertions, and one of them is the
only defence against a specific failure.** Both scripts self-check their immutables, but that runs
during _simulation_. `DeployBridgeUpgradeL2` deploys the resolver proxy and then passes its address
as a constructor argument to the `Bridge` — so if the deployer's on-chain nonce differs at broadcast
time from what the simulation assumed, the `CREATE` addresses shift while the `Bridge` creation
calldata, with the _simulated_ resolver address already baked into it, does not. The result is a
deployed implementation whose `resolver` immutable points at a contract that does not exist, and
nothing in the script catches it. `cast call <BRIDGE_NEW_IMPL_L2> "resolver()(address)"`, compared
against the logged `L2_SHARED_RESOLVER`, is what catches it. Run it, and read the answer rather than
just checking that the call succeeded.

The L1 immutables cannot dangle the same way — all four are library constants — so those four checks
serve the narrower purpose of confirming the intended creation code and argument order landed.

**Getters and a non-zero code size do not authenticate the bytecode.** They confirm the constructor
arguments landed; they cannot distinguish the reviewed `Bridge` and `DefaultResolver` from a
contract that answers the same getters and does something else. The `codehash` comparison above and
the explorer verification in the Deployment section are what close that gap, and the resolver's
implementation slot is what closes it for the one address here that is a proxy rather than a bare
implementation.

### After execution

```bash
# Implementation slots now point at the new implementations.
cast storage 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <L1_RPC>
cast storage 0x1670000000000000000000000000000000000001 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url https://rpc.mainnet.taiko.xyz

# Smoke test: this is the exact resolver path that would revert if the L2 wiring were wrong.
# Must return (true, 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC).
cast call 0x1670000000000000000000000000000000000001 \
  "isDestChainEnabled(uint64)(bool,address)" 1 --rpc-url https://rpc.mainnet.taiko.xyz

# The chain-167000 registration (L2 action 2 / actions[1]), which no other check covers.
# Must return 0x1670000000000000000000000000000000000001.
cast call <L2_SHARED_RESOLVER> "resolve(uint256,bytes32,bool)(address)" \
  167000 0x6272696467650000000000000000000000000000000000000000000000000000 true \
  --rpc-url https://rpc.mainnet.taiko.xyz
```

```bash
# The production L2 message must have landed DONE, not RETRIABLE. Take <L2_GOVERNANCE_MSG_HASH>
# from the `MessageSent(bytes32 indexed msgHash, Message)` event the L1 bridge emits when the
# proposal's sendMessage action executes; it is the first indexed topic on that log.
# `2` is Status.DONE, `1` is Status.RETRIABLE, `0` means the message was never processed.
cast call 0x1670000000000000000000000000000000000001 \
  "messageStatus(bytes32)(uint8)" <L2_GOVERNANCE_MSG_HASH> \
  --rpc-url https://rpc.mainnet.taiko.xyz
```

Both `cast storage` results must equal the deployed implementation addresses, left-padded to 32
bytes.

The status check exists because production execution carries the **same swallowing hazard** the
rehearsal did: 1.10.0's `_invokeMessageCall` uses a raw `call`, so a failed invocation becomes
`Status.RETRIABLE` without reverting `processMessage`, and the L1 side would look entirely healthy.
The implementation-slot check above would already expose that, but the status makes the failure
mode legible directly, and it changes what recovery looks like.

If the status reads `RETRIABLE`, **diagnose before retrying.** `retryMessage` replays the _same_
calldata, so it only helps where the failure was not in the message itself — the realistic case is
gas starvation, since the `destOwner` calling `retryMessage` forwards all remaining gas instead of
the `l2GasLimit`-derived budget. A failure caused by the message's own content — a wrong
`L2_SHARED_RESOLVER` or `BRIDGE_NEW_IMPL_L2` baked into the actions, or a malformed action array —
will fail identically on every retry and needs a new proposal. Establish which case you are in from
the L2 execution trace first; do not retry blindly.

The `isDestChainEnabled(1)` smoke test is the one that matters: it is the call that reverts if the
resolver wiring is wrong, and it is served by the new implementation reading the new resolver — so
it covers the chain-1 registration and the L2 upgrade at once. The last command is the only check on
the chain-167000 registration, since nothing reads that entry today.

Post-execution, add dated bullets to `deployments/mainnet-contract-logs-L1.md` and
`deployments/mainnet-contract-logs-L2.md` for the four newly deployed contracts — the L1 `Bridge`
implementation, the L2 `DefaultResolver` implementation, its `ERC1967Proxy`, and the L2 `Bridge`
implementation (the resolver's proxy and implementation share one `#### shared_resolver` entry, as
those files are structured) — and add a `LibL2Addrs.SHARED_RESOLVER` constant for the new resolver.

## Fork Rehearsal

The repository has no fork tests and CI configures no RPC endpoints, so this rehearsal ran locally
from a throwaway Foundry test kept in the session scratchpad. It is **not committed and does not
re-run** — what follows is snapshot evidence captured on 2026-08-31, not a regression test. The cap
itself is separately covered by committed unit tests that #22077 added
(`MessageReceiver_CreatingFreshStorageSlots.sol`, plus cases in `Bridge2_processMessage.t.sol` and
`Bridge2_recallMessage.t.sol`); the rehearsal targets what unit tests cannot reach, namely the
upgrade against live mainnet state.

Both legs ran on `forge 1.5.1-stable`, forking each chain at its head.

### L1 leg

Chain head immediately before the run: `25875170`.

```
Compiling 1 files with Solc 0.8.30
Solc 0.8.30 finished in 1.36s
Compiler run successful!

Ran 1 test for test/layer1/proposals/Proposal0023Rehearsal.t.sol:Proposal0023Rehearsal
[PASS] test_l1_upgrade() (gas: 3092291)
Logs:
  L1 impl slot now: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 2.37s (2.36s CPU time)

Ran 1 test suite in 2.37s (2.37s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

The test upgraded the live L1 proxy by pranking the DAO controller, then asserted all four
immutables and that `isDestChainEnabled(167000)` returns
`(true, 0x1670000000000000000000000000000000000001)`.

### L2 leg

Chain head immediately before the run: `10785761`.

```
No files changed, compilation skipped

Ran 1 test for test/layer1/proposals/Proposal0023Rehearsal.t.sol:Proposal0023Rehearsal
[PASS] test_l2_selfUpgradeThroughProcessMessage() (gas: 4434537)
Logs:
  L2 nextMessageId before/after: 10101 10102

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 8.98s (8.97s CPU time)

Ran 1 test suite in 8.98s (8.97s CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```

The test deployed the resolver and implementation the deploy script deploys, then delivered the
three L2 actions the way governance actually will — as a `processMessage` call on the L2 bridge
carrying the `DelegateController.onMessageInvocation` payload, not by pranking the DelegateController
directly. That is what exercises the mid-call self-upgrade. It then asserted `isDestChainEnabled(1)`,
that `nextMessageId()` and `owner()` survived the 1.10.0 → `main` jump, that `resolver()`,
`quotaManager()` and `pauser()` read as expected, and that a fresh outbound `sendMessage` increments
`nextMessageId`.

### What counts as success here, and what does not

**"The transaction passed" is not evidence the upgrade worked**, and anyone re-running this rehearsal
needs to know that. The 1.10.0 `_invokeMessageCall` uses a raw `call` and **swallows** a reverting
invocation into `Status.RETRIABLE` without reverting `processMessage`. A silently failed upgrade
would still have produced a passing transaction and a green test line.

Two observations together rule that out. First, the implementation-slot assertion: the slot flipped
to the new implementation. Second, the status the bridge emitted:

```
├─ emit MessageStatusChanged(msgHash: 0xc3e89e557a5db0feebcb420ab5f64929d4369ba85532d59abf3ec749b3d680d9, status: 2)
```

`status: 2` is `Status.DONE` with `StatusReason.INVOCATION_OK` — the invocation ran and succeeded. A
swallowed revert would have shown `RETRIABLE` instead. **Check both when re-running.**

### What the rehearsal does not establish

The rehearsal proves the _mechanism_, not the production addresses. The implementations it upgraded
to were deployed by the test inside its own fork — `0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f` on
L1 and `0xF62849F9A0B5Bf2913b396098F7c7019b51A820a` on L2. Neither is a production address, and
neither should ever appear in the proposal. The [Verification](#verification) checks against the real
deployed addresses still have to be run.

One further caveat on the L2 leg: a signal proof cannot be synthesised on a fork, so
`ISignalService.proveSignalReceived` was mocked to return `0`. Nothing else was mocked — the
post-upgrade `sendMessage` reached the real deployed L2 SignalService and emitted a real
`SignalSent`. The signal service is not what this rehearsal exercises.
