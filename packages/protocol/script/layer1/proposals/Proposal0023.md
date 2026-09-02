# PROPOSAL-0023: Upgrade the L1 and L2 Bridges and ERC20 Vaults

## Executive Summary

Proposal0023 ships two already-merged changes to production by upgrading four proxies, two per
chain. **No contract source changes ship with this proposal** — deploy scripts, the DAO proposal, a
runbook and tests only.

**The bridges.** [PR #22077](https://github.com/taikoxyz/taiko-mono/pull/22077) raised
`Bridge._SEND_ETHER_GAS_LIMIT` from 35,000 to 135,000 gas. That constant is the `CALL` gas operand
the bridge uses whenever it sends Ether to a message recipient. EIP-8037 (state-creation repricing,
scheduled for Glamsterdam) charges 64 state bytes × 1,530 gas/byte = 97,920 gas to create one fresh
storage slot. In any realistic claim transaction — one that does not buy gas beyond the 16.7M
per-transaction execution cap, and so has an empty state-gas reservoir — that charge is deducted
from the callee frame's own gas. A smart wallet that writes a single fresh slot on its receive path
would therefore run out of gas under the old 35,000 cap, and because a failed Ether send reverts
message processing, that wallet's inbound messages would become permanently unclaimable. The new cap
is the legacy 35,000 callee budget plus one slot-creation charge, rounded up: 35,000 + 97,920 =
132,920 → 135,000. Wallets that fit before the fork still fit after it, as long as their receive
path creates at most one storage slot.

**The ERC20 vaults.** [PR #22093](https://github.com/taikoxyz/taiko-mono/pull/22093) added two
entrypoints to `ERC20Vault`: `sendTokenWithPermit`, which consumes an EIP-2612 `permit` signature so
no separate `approve` transaction is needed, and `sendTokenWithPermit2`, which pulls the tokens
through Uniswap's Permit2 (`0x000000000022D473030F116dDEE9F6B43aC78BA3`, deployed at that address on
both chains) and so works for every ERC20 whether or not it implements EIP-2612. Both are opt-in
additions on the send path; `sendToken`, deliveries and recalls are unchanged.

Both changes are compiled into implementations, so they reach production only when the proxies are
pointed at new ones. **Proposal0023 is that bundle, and nothing else.** #22077, #22093, #22058
(transient-storage unification) and #22059 (gas-schedule docs) are all already on `main`.

On **L1** both legs are like-for-like redeploys. Diffing each implementation's whole dependency tree
from Proposal0017's commit `b73608696` to `main` turns up, for the bridge, `Bridge.sol`,
`EssentialContract.sol` and `LibNames.sol`; for the vault, `ERC20Vault.sol`, the new `IPermit2.sol`,
`EssentialContract.sol` and `LibNames.sol`. `LibNames` only gained an unused `B_PRECONF_SLASHER`
constant, `EssentialContract` carries the transient-storage refactor — which reuses the exact slot
constant the live implementations already use — and the remaining two files carry the cap and the
permit entrypoints respectively.

On **L2** neither leg is like-for-like. The L2 bridge and the L2 ERC20 vault both still run protocol
1.10.0 implementations from October 2024, which predate the resolver refactor, so they additionally
need a resolver that speaks the modern `IResolver` interface — and the vault needs a modern
`BridgedERC20` implementation behind it. [Why L2 Needs a New Resolver](#why-l2-needs-a-new-resolver)
covers both.

The proposal executes **3 top-level L1 actions** and **7 L2 actions**.

**Where this stands.** The bridge-side contracts were deployed on 2026-08-31. The vault-side
implementations — one `ERC20Vault` per chain and one `BridgedERC20` on L2 — are **not deployed
yet**: their constants in `Proposal0023.s.sol` are `address(0)` placeholders, `P=0023 pnpm proposal`
deliberately reverts with `ImplementationNotDeployed()` until they are filled in, and
`Proposal0023.action.md` does not exist yet. [Deployment](#deployment) lists what is left.

## Scope

Seven contracts are deployed ahead of the vote — two `Bridge` implementations, two `ERC20Vault`
implementations, a `BridgedERC20` implementation on L2, plus a `DefaultResolver` implementation and
its `ERC1967Proxy` on L2. The proposal then re-points four proxies and populates the new resolver:

| Chain | Contract                                                                 | Change                                                                                    |
| ----- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| L1    | Bridge proxy `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`                | implementation → `0xA15dca0A72da684f20e0FC708DECFb230a715462`                             |
| L1    | ERC20Vault proxy `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`            | implementation → `ERC20_VAULT_NEW_IMPL_L1` (pending deployment)                           |
| L2    | Bridge proxy `0x1670000000000000000000000000000000000001`                | implementation → `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb`                             |
| L2    | ERC20Vault proxy `0x1670000000000000000000000000000000000002`            | implementation → `ERC20_VAULT_NEW_IMPL_L2` (pending deployment)                           |
| L2    | New `DefaultResolver` proxy `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | `bridge` and `erc20_vault` registered for chains 1 and 167000; `bridged_erc20` for 167000 |

Explicitly **not** touched by this proposal:

- **The L2 NFT vaults** — `ERC721Vault` `0x1670000000000000000000000000000000000003` and
  `ERC1155Vault` `0x1670000000000000000000000000000000000004`. They are also on 1.10.0
  implementations and keep resolving through the legacy registry.
- **The legacy L2 `AddressManager` `0x1670000000000000000000000000000000000006`.** It is neither
  migrated nor retired nor modified. It keeps serving the NFT vaults, and — this matters for the
  vault leg — every bridged token the 1.10.0 vault ever deployed, all of which resolve the vault
  through it by name and keep working because the vault's proxy address does not change.
- **`Bridge.sol`, `ERC20Vault.sol`, `BridgedERC20.sol` and the gas constants.** Those changed in
  #22077 and #22093, which are already merged. This proposal only ships the already-merged code.
- **The L1 resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`.** Both L1 legs reuse it unchanged;
  it already carries every name the new implementations read. Only L2 gets a new resolver.
- **Ownership.** No `transferOwnership`, no `acceptOwnership`, no initializer call on any live
  contract. The new L2 resolver is initialised with the DelegateController as owner at deploy time,
  before the proposal runs.
- **Hoodi and every other network.** This proposal targets mainnet governance only.

**Known, pre-existing, and not addressed here — the L1 `bridged_erc20`.** The L1 shared resolver
answers `bridged_erc20` with `0x65666141a541423606365123Ed280AB16a09A2e1`, the July 2024
implementation whose only initializer is the seven-argument, address-manager based
`init(address,address,address,uint256,uint8,string,string)` (selector `0xbb86ef93`). The live L1
vault, since Proposal0017, initialises new bridged tokens through the six-argument
`IBridgedERC20Initializable.init` (selector `0x6c0db62b`), which that implementation does not have —
both facts read from the deployed bytecode. So the first delivery to L1 of a token that is canonical
on another chain already reverts today, inside `_deployBridgedToken`, and this proposal neither fixes
nor worsens that: the new L1 vault calls the same initializer. The fix is the L2 fix mirrored —
deploy a `BridgedERC20(L1.ERC20_VAULT)` and register it as `bridged_erc20` on the L1 shared resolver
— which is one deploy plus one action and could be folded into this proposal. It is left out because
it is a separate defect with its own decision to make, not because it is hard.

## Current State

Verified on-chain 2026-09-02.

|           | proxy                                        | owner                                                                                | live impl                                    | impl provenance                               |
| --------- | -------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- | --------------------------------------------- |
| L1 bridge | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0x1c94D798CFA08F396E5BA9F81697289c53273381` | Proposal0017, 2026-06-29, commit `b73608696`  |
| L1 vault  | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` | Proposal0017, 2026-06-29, commit `b73608696`  |
| L2 bridge | `0x1670000000000000000000000000000000000001` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83` | protocol 1.10.0, 2024-10-31, commit `9345f14` |
| L2 vault  | `0x1670000000000000000000000000000000000002` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0xb96AbB41b01E3ad519D00E80355a1c3801910F62` | protocol 1.10.0, 2024-10-31, commit `9345f14` |

**The live L1 implementations are a `MainnetBridge` and a `MainnetERC20Vault`, not a `Bridge` and
an `ERC20Vault`.** Those were the L1-only subclasses that #22058 deleted; this proposal deploys the
unified shared contracts. Reviewers diffing "the live implementation" against `Bridge.sol` or
`ERC20Vault.sol` should expect that type change, and block explorers will show different contract
names once the new implementations are verified. It is not a behavioural change: the subclasses
existed only to override the reentrancy lock (and, for the bridge, the call context) onto transient
storage, and #22058 folded both mechanisms into the base contracts at **byte-identical slot
constants** —

|                 | `MainnetBridge` / `MainnetERC20Vault` / `LibFasterReentryLock` | `Bridge` / `ERC20Vault` on `main` |
| --------------- | -------------------------------------------------------------- | --------------------------------- |
| call context    | `_CTX_SLOT = 0xe4ece821…dbadc2b9` (bridge only)                | identical                         |
| reentrancy lock | `_REENTRY_SLOT = 0xa5054f72…31d9721b`                          | identical                         |

— the reentry constant is present verbatim in the live vault implementation's bytecode. So the claim
that the only behavioural deltas on L1 are the send cap and the permit entrypoints holds. Storage
layout is unchanged.

The generation gap between the two chains shows up in what each live implementation answers:

- The L1 implementations answer `resolver()` → `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` and
  `quotaManager()` → `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC`; `addressManager()` reverts.
- The L2 implementations answer `addressManager()` → `0x1670000000000000000000000000000000000006`;
  `resolver()` and `quotaManager()` (and, on the bridge, `signalService()` and `pauser()`) **all
  revert**. That is the 1.10.0 signature: those are immutables that did not exist yet.

The immutables on the live L1 proxies, which the new L1 implementations must reproduce exactly:

| Contract | Immutable         | Value                                        | `LibL1Addrs` constant                          |
| -------- | ----------------- | -------------------------------------------- | ---------------------------------------------- |
| bridge   | `resolver()`      | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `SHARED_RESOLVER`                              |
| bridge   | `signalService()` | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `SIGNAL_SERVICE`                               |
| bridge   | `quotaManager()`  | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `QUOTA_MANAGER`                                |
| bridge   | `pauser()`        | `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` | `MULTISIG_ADMIN_TAIKO_ETH` (`admin.taiko.eth`) |
| vault    | `resolver()`      | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `SHARED_RESOLVER`                              |
| vault    | `quotaManager()`  | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `QUOTA_MANAGER`                                |

`DeployERC20VaultUpgradeL1` reads the two vault values back from the live proxy before it
broadcasts, so a drifted `LibL1Addrs` constant aborts the run rather than baking into the new
immutables.

The new L2 implementations instead take the newly deployed resolver, and **zero** for
`quotaManager` (both), `pauser` (bridge) and the bridge's `SIGNAL_SERVICE`
`0x1670000000000000000000000000000000000005`. Zero preserves today's behaviour rather than removing
anything: `quota_manager@167000`, `chain_watchdog@167000` and `bridge_watchdog@167000` are all unset
on the legacy L2 registry, so L2 has no Ether quota and no token quota today and only the owner can
pause. The 1.10.0 `Bridge` has no `receive()` at all, so the new pauser-only `receive()` is strictly
more permissive than the status quo, not less. The new `BridgedERC20` takes the vault **proxy**
`0x1670000000000000000000000000000000000002` as its `erc20Vault` immutable.

Other live values a reviewer will want:

- L2 bridge balance ≈ **999,998,918.6 ETH**. This is the L2 premint float and it is what the L2
  bridge leg puts at risk; it moves with bridge traffic, so re-read it at execution time rather than
  trusting the digits here.
- L2 bridge `paused()` = `false` and L2 vault `paused()` = `false`. The first is a precondition,
  not trivia: `processMessage` is `whenNotPaused`, so the L2 leg cannot land while the bridge is
  paused. `nextMessageId()` is deliberately not quoted here — it climbs with every outbound message,
  and the fork test reads it dynamically rather than pinning a value.
- `DelegateController.lastExecutionId()` = `1`.
- L2 bridged tokens the 1.10.0 vault deployed, which the fork rehearsal uses as its canary:
  bridged USDT `0x2DEF195713CF4a606B49D07E520e22C17899a736` and bridged WETH
  `0x0038cbAC16db1E2EA27f976784235090d9751CD4`, both `ERC1967Proxy` over the V1 `BridgedERC20`
  `0x0167000000000000000000000000000000010096`, both answering `addressManager()` →
  `0x1670…0006`. Bridged USDC `0x07d83526730c7438048D55A4fc0b850e2aaB6f0b` and bridged TAIKO
  `0xA9d23408b9bA935c230493c40C73824Df71A0975` were linked with `changeBridgedToken` and are not
  vault-deployed proxies.

## Why L2 Needs a New Resolver

`Bridge` on `main` looks up `LibNames.B_BRIDGE` through `IResolver.resolve(uint256,bytes32,bool)`
(selector `0x6c6563f6`) at exactly three call sites — `Bridge.sol:491` (`isDestChainEnabled`),
`Bridge.sol:607` (`_proveSignalReceived`) and `Bridge.sol:658` (`_isSignalReceived`).

`ERC20Vault` on `main` resolves through the same interface at six:

| Site                                   | Name            | Chain id passed          | Reached by                                     |
| -------------------------------------- | --------------- | ------------------------ | ---------------------------------------------- |
| `BaseVault.sol:56` (`onlyFromNamed`)   | `bridge`        | `block.chainid` = 167000 | every delivery (`onMessageInvocation`)         |
| `BaseVault.sol:60`                     | `erc20_vault`   | `ctx.srcChainId` = 1     | every delivery — the message must come from it |
| `BaseVault.sol:69`                     | `erc20_vault`   | `_op.destChainId` = 1    | every `sendToken`, as the forbidden recipient  |
| `ERC20Vault.sol:415`                   | `erc20_vault`   | `_op.destChainId` = 1    | every `sendToken`, as the message's `to`       |
| `ERC20Vault.sol:424`                   | `bridge`        | `block.chainid` = 167000 | every `sendToken`, as the bridge it calls      |
| `ERC20Vault.sol:482` (`onlyFromNamed`) | `bridge`        | `block.chainid` = 167000 | every recall (`onMessageRecalled`)             |
| `ERC20Vault.sol:664`                   | `bridged_erc20` | `block.chainid` = 167000 | the first delivery of a token not seen before  |

- The L1 resolver `0x8Efa0156…` is a modern `DefaultResolver`. It answers every one of these for
  both chains — `bridge`, `erc20_vault` and `bridged_erc20` for chain 1, `bridge` and `erc20_vault`
  for chain 167000 — which is why the L1 legs need no registration.
- The L2 registry `0x1670000000000000000000000000000000000006` is the 1.10.0 `AddressManager`.
  `resolve(uint256,bytes32,bool)` **reverts** — the selector does not exist on it. Only
  `getAddress(uint64,bytes32)` works.

Pointing either new implementation at `0x1670…0006` would therefore revert every `sendMessage`,
`processMessage`, `sendToken` and delivery on L2. L2 needs a registry that answers the modern
selector.

The fix mirrors what L1 already did. Rather than migrating the legacy registry, L1 deployed a
separate `shared_resolver` in May 2025 and moved onto it only the contracts that received new
implementations (bridge, `erc20_vault`). The L1 NFT vaults still resolve through the legacy
`shared_address_manager` today. Proposal0023 replays that split on L2: a new `DefaultResolver`
serves the new bridge and the new vault, the untouched NFT vaults keep using `0x1670…0006`, and only
the names the two migrated contracts actually read are registered.

### Which registrations are load-bearing

Every registration but one is read by the new code on a hot path:

| Registration                     | Read by                                                                                          |
| -------------------------------- | ------------------------------------------------------------------------------------------------ |
| `bridge` for chain 1             | the bridge, on every send, recall and claim — all three bridge sites pass the counterparty id    |
| `bridge` for chain 167000        | the vault, on every delivery, recall and `sendToken` — never by the bridge itself                |
| `erc20_vault` for chain 1        | the vault, on every delivery and every `sendToken`                                               |
| `erc20_vault` for chain 167000   | nothing today; registered for symmetry with the L1 resolver, which carries its own chain's entry |
| `bridged_erc20` for chain 167000 | the vault, on the first delivery of a canonical token it has not seen before                     |

The bridge's three call sites use the explicit-`_chainId` overload of `resolve`, never the
`block.chainid` overload, and every bridge operation that reaches them passes the _counterparty_
chain id, because a same-chain check runs first in each case:

| Caller              | Reaches a lookup at | Chain id passed        | Same-chain check                                              |
| ------------------- | ------------------- | ---------------------- | ------------------------------------------------------------- |
| `sendMessage`       | `Bridge.sol:207`    | `_message.destChainId` | `diffChain(_message.destChainId)` at `:195`                   |
| `recallMessage`     | `Bridge.sol:246`    | `_message.destChainId` | `diffChain(_message.destChainId)` at `:235`                   |
| `processMessage`    | `Bridge.sol:311`    | `_message.srcChainId`  | `srcChainId == block.chainid` reverts at `:292`               |
| `isMessageFailed`   | `Bridge.sol:451`    | `_message.destChainId` | returns `false` unless `srcChainId == block.chainid`, `:449`  |
| `isMessageReceived` | `Bridge.sol:473`    | `_message.srcChainId`  | returns `false` unless `destChainId == block.chainid`, `:472` |

The chain-167000 `bridge` entry, which the first version of this proposal registered only for
symmetry, is now load-bearing: it is what `onlyFromNamed(LibNames.B_BRIDGE)` at `BaseVault.sol:56`
resolves on every delivery to the upgraded vault.

### Why `bridged_erc20` must be a new implementation

The L2 registry names `bridged_erc20` = `0x98161D67f762A9E589E502348579FA38B1Ac47A8`, the same July
2024 lineage as L1's. The obvious move — register that address on the new resolver too — does not
work, and would fail silently until the first new token arrived:

- `ERC20Vault._deployBridgedToken` (`ERC20Vault.sol:652`) creates each bridged token as
  `new ERC1967Proxy(resolve("bridged_erc20"), init)` where `init` is the six-argument
  `IBridgedERC20Initializable.init(owner, srcToken, srcChainId, decimals, symbol, name)`, selector
  `0x6c0db62b`. The legacy implementation's bytecode carries only the seven-argument
  `init(address,address,address,uint256,uint8,string,string)`, selector `0xbb86ef93`, and no
  fallback. The proxy constructor's delegatecall would hit no function and revert, the delivery
  would revert with it, and the bridge would park the message as `RETRIABLE` — for every first-time
  token, forever.
- Even with a matching initializer the legacy token would authorise `mint`/`burn` through
  `AddressResolver`, i.e. `IAddressManager(addressManager).getAddress(uint64,bytes32)` — a selector
  the new `DefaultResolver` does not have either.

`BridgedERC20` on `main` has neither problem: it takes the vault as a constructor immutable
(`erc20Vault`) and authorises `mint`/`burn` against that address directly, with no resolver at all.
`DeployERC20VaultUpgradeL2` deploys it with the vault **proxy** as the immutable, so tokens deployed
after this proposal keep working across future vault upgrades too.

Existing bridged tokens are unaffected in the other direction: they were initialised with the legacy
registry as their address manager, and it still names `erc20_vault` = the unchanged proxy
`0x1670…0002`, so their `onlyFromNamed(erc20_vault)` guards keep admitting the upgraded vault. The
fork rehearsal mints bridged USDT through exactly that path after the upgrade.

## Upgrade Safety

### Storage layout

Slot boundaries are identical between the 1.10.0 lineage and `main` for both contracts. Bridge:

| slot    | 1.10.0                                                                                        | `main`                               |
| ------- | --------------------------------------------------------------------------------------------- | ------------------------------------ |
| 151     | `AddressResolver.addressManager`                                                              | `__gapFromOldAddressResolver[0]`     |
| 152–200 | `AddressResolver.__gap[49]`                                                                   | `__gapFromOldAddressResolver[1..49]` |
| 201.0   | `__reentry`                                                                                   | `__reentry`                          |
| 201.1   | `__paused`                                                                                    | `__paused`                           |
| 201.2   | `lastUnpausedAt` (uint64)                                                                     | unused                               |
| 202–250 | `__gap[49]`                                                                                   | `__gap[49]`                          |
| 251–300 | `__reserved1`/`nextMessageId`/`messageStatus`/`__ctx`/`__reserved2`/`__reserved3`/`__gap[44]` | identical                            |

ERC20Vault, from `forge inspect ERC20Vault storage-layout` at commit `9345f14` against
`contracts/shared/vault/ERC20Vault_Layout.sol` on `main`:

| slot    | 1.10.0                                      | `main`                               |
| ------- | ------------------------------------------- | ------------------------------------ |
| 0–150   | `Initializable` / `Ownable2StepUpgradeable` | identical                            |
| 151     | `AddressResolver.addressManager`            | `__gapFromOldAddressResolver[0]`     |
| 152–200 | `AddressResolver.__gap[49]`                 | `__gapFromOldAddressResolver[1..49]` |
| 201.0   | `__reentry`                                 | `__reentry`                          |
| 201.1   | `__paused`                                  | `__paused`                           |
| 201.2   | `lastUnpausedAt` (uint64)                   | unused                               |
| 202–250 | `__gap[49]`                                 | `__gap[49]`                          |
| 251–300 | `BaseVault.__gap[50]`                       | identical                            |
| 301     | `bridgedToCanonical`                        | identical                            |
| 302     | `canonicalToBridged`                        | identical                            |
| 303     | `btokenDenylist`                            | identical                            |
| 304     | `lastMigrationStart`                        | identical                            |
| 305–350 | `__gap[46]`                                 | identical                            |

`lastUnpausedAt` was dropped from `EssentialContract`, leaving stale bytes in slot 201 that nothing
reads. `addressManager` is absorbed by the gap that exists for exactly this reason — which is why
the live L2 proxies still answer `addressManager()` with `0x1670…0006`.

The decisive precedent: **the L1 bridge and the L1 vault already made this exact jump.** Both went
from the same 1.10.0 implementation lineage (commit `9345f14`) straight to their current
implementations in Proposal0017 on 2026-06-29, and the vault has custodied mainnet deposits on
that layout since. L2 is the same migration, two months later.

### ABI

The vault's `BridgeTransferOp` struct, its five events (`BridgedTokenDeployed`,
`BridgedTokenChanged`, `TokenSent`, `TokenReleased`, `TokenReceived`) and its errors are identical
between 1.10.0 and `main`, so `sendToken`'s selector, the relayer, the event indexer and the bridge
UI are unaffected by the L2 vault jump. `main` adds `sendTokenWithPermit`, `sendTokenWithPermit2`,
the `VAULT_PERMIT_NO_ALLOWANCE` error and the `PERMIT2` constant, and drops the second parameter of
`init`, which no live contract calls.

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

The vault upgrade is not a self-upgrade: the vault proxy is owned by the same DelegateController, the
vault is not on the call stack while the batch executes, and `upgradeTo` on it is a plain owner
upgrade. It is ordered **before** the bridge swap so that the bridge's self-upgrade is the final
action and the batch makes no further call once the bridge's own code has been swapped under its
frame. The 1.10.0 vault's `_authorizeUpgrade` is the same `onlyOwner`, no `nonReentrant`.

This is the part of the proposal that carries real risk, and it is the part
`test/layer1/proposals/Proposal0023Fork.t.sol` was written to exercise against live mainnet state.
Run it with `L1_FORK_URL` and `L2_FORK_URL` set; without them it skips, since CI configures no RPC
endpoints. The rehearsal executes the actions `Proposal0023.s.sol` encodes — not a hand-written copy
— and after each leg bridges tokens through the upgraded contracts: on L1, WETH out through the new
vault and bridge; on L2, USDT in through the existing bridged token, a never-seen token in through
a freshly deployed `BridgedERC20`, and bridged USDT back out. It passed on both forks on 2026-09-02.

### EVM version

`foundry.toml` pins `evm_version = "osaka"` for both `profile.layer2` and `profile.shared`, so
`TSTORE`/`TLOAD` are available on L2.

## Action Order

### L1 — 3 top-level actions

1. `upgradeTo(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, 0xA15dca0A72da684f20e0FC708DECFb230a715462)` — point the mainnet
   bridge at the implementation carrying the EIP-8037 send cap.
2. `upgradeTo(0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, ERC20_VAULT_NEW_IMPL_L1)` — point the
   mainnet ERC20 vault at the implementation carrying the permit and Permit2 entrypoints.
3. `sendMessage(...)` on `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` — carries the L2 batch below to
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
resolver in the same transaction it goes live. The L1 fork rehearsal executes all three actions in
this order from the DAO controller; see [Deployment](#deployment) for the dry run that proves it
against live state before the vote.

### L2 — 7 actions, `l2ExecutionId = 0`, `l2GasLimit = 5_000_000`

Numbered here from 1; in `Proposal0023.s.sol` these are `actions[0]` through `actions[6]`.

1. (`actions[0]`) `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984.registerAddress(1, LibNames.B_BRIDGE, 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC)`
   — what the new bridge implementation reads.
2. (`actions[1]`) `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984.registerAddress(167000, LibNames.B_BRIDGE, 0x1670000000000000000000000000000000000001)`
   — what the new vault implementation reads on every delivery, recall and send.
3. (`actions[2]`) `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984.registerAddress(1, LibNames.B_ERC20_VAULT, 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab)`
   — what the new vault implementation reads on every delivery and send.
4. (`actions[3]`) `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984.registerAddress(167000, LibNames.B_ERC20_VAULT, 0x1670000000000000000000000000000000000002)`
   — registered for symmetry with the L1 resolver; read by nothing today.
5. (`actions[4]`) `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984.registerAddress(167000, LibNames.B_BRIDGED_ERC20, BRIDGED_ERC20_NEW_IMPL_L2)`
   — the implementation behind every bridged token the new vault deploys.
6. (`actions[5]`) `upgradeTo(0x1670000000000000000000000000000000000002, ERC20_VAULT_NEW_IMPL_L2)` —
   the plain owner upgrade of the vault.
7. (`actions[6]`) `upgradeTo(0x1670000000000000000000000000000000000001, 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb)` — the
   mid-call self-upgrade described above, deliberately last.

`registerAddress` is encoded with the `LibNames` constants (`bytes32("bridge")`,
`bytes32("erc20_vault")`, `bytes32("bridged_erc20")`), not hand-written literals.

**On the ordering.** All seven L2 actions execute in a **single transaction**:
`DelegateController.onMessageInvocation` calls `_executeActions` once, and
`Controller._executeActions` (`contracts/shared/governance/Controller.sol:58-64`) loops the whole
array in one frame. `upgradeTo` reads no name from the resolver, so an upgrade-first ordering would
revert nothing and would leave exactly the same end state — there is no window inside the batch in
which an outside caller could reach a new implementation against an empty registry. The
register-then-upgrade order shipped here is the correct, defensive choice, not a correctness
requirement.

The hazard the ordering is defending against is a different one: **the registrations must not land in
a later transaction or a later proposal.** If an upgrade shipped alone and the registrations
followed separately, then between the two the L2 bridge or vault would be live with an
implementation reading an empty resolver, and every `sendMessage`, `processMessage`, `sendToken` and
delivery on L2 would revert until the second transaction landed. Keeping all seven in one message is
what closes that window. Reviewers should check that the five registrations and the two upgrades are
present in the same bundle, not that they appear in a particular sequence within it.

### Parameter choices

- **`l2ExecutionId = 0`**, matching Proposal0007 and Proposal0011. `DelegateController` accepts
  `executionId == 0` as "unordered" or `executionId == ++lastExecutionId` as ordered.
  `lastExecutionId()` is currently `1`, so the ordered value would be `2` — which adds replay and
  ordering protection but breaks if any other L2 proposal executes first. Zero is the conventional
  choice here.
- **`l2GasLimit = 5_000_000`**, matching Proposal0011, which also bundled proxy upgrades. The seven
  actions need well under 400k. `Bridge.GAS_RESERVE` (800,000) and the 1.10.0 bridge's calldata
  charge (39,936 gas for this message's 2,052 bytes of data) are deducted from the limit before
  invocation, leaving a relayer-driven invocation 4,160,064 gas — pinned by the fork test's relayer
  case, which processes the message under exactly that budget.
- **Resolver ownership.** The resolver is initialised with `DELEGATE_CONTROLLER` as owner at deploy
  time, and the five `registerAddress` calls are proposal actions so they are auditable in the DAO
  calldata. The alternative — registering at deploy time and then handing ownership over — would
  need an extra `acceptOwnership` action, because `EssentialContract` is `Ownable2Step`.

## Deployment

### Bridge side — done on 2026-08-31

The addresses are recorded in Deployed Addresses below and are baked into `Proposal0023.s.sol`; the
commands are kept so the deployment can be reproduced or audited.

```bash
# Ethereum mainnet
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployBridgeUpgradeL1.s.sol:DeployBridgeUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast
```

```bash
# Taiko L2
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/mainnet/DeployBridgeUpgradeL2.s.sol:DeployBridgeUpgradeL2 \
  --rpc-url https://rpc.mainnet.taiko.xyz --broadcast
```

`DeployBridgeUpgradeL1` logs `BRIDGE_NEW_IMPL_L1`; `DeployBridgeUpgradeL2` logs
`L2_SHARED_RESOLVER`, its implementation, and `BRIDGE_NEW_IMPL_L2`. Do **not** re-run these: a
second run would deploy a second set of contracts that the constants do not point at.

### Vault side — still to do

```bash
# Ethereum mainnet
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployERC20VaultUpgradeL1.s.sol:DeployERC20VaultUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast
```

```bash
# Taiko L2
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/mainnet/DeployERC20VaultUpgradeL2.s.sol:DeployERC20VaultUpgradeL2 \
  --rpc-url https://rpc.mainnet.taiko.xyz --broadcast
```

Both scripts deploy only. Neither upgrades a proxy nor calls an initializer on a live contract.
`DeployERC20VaultUpgradeL1` logs `ERC20_VAULT_NEW_IMPL_L1`; `DeployERC20VaultUpgradeL2` logs
`BRIDGED_ERC20_NEW_IMPL_L2` and `ERC20_VAULT_NEW_IMPL_L2`. That is **three** more contracts across
the two chains, seven in total. Both scripts read the live chain before broadcasting — the L1 one
checks the live vault's immutables against `LibL1Addrs`, the L2 one checks that the resolver at
`L2_SHARED_RESOLVER` is owned by the DelegateController — and both check the new immutables after.

Verify all three on the block explorers before the proposal is created, so a delegate can read the
source behind each address rather than trusting the deployer. Use the same compiler settings the
branch pins — `solc 0.8.30`, `optimizer_runs = 200`, `evm_version = "osaka"` — and the constructor
arguments the scripts pass. `osaka` applies on both chains: `profile.default` sets it and the L1
profile inherits, so the L1 and L2 contracts verify under the same settings.

Do the explorer verification **first**, then run the `forge verify-bytecode` commands in the
pre-execution checklist. They are not an independent second route — both go through the same
Etherscan API, and `verify-bytecode` fails without a key. What it adds is a different comparison,
not different infrastructure: the explorer tells a delegate what source the operator submitted,
while `verify-bytecode` compares the deployed creation code against a build of **this commit** on
the machine running it.

> **The `verify-bytecode` findings below were measured on `forge 1.5.1-stable`, but this repo pins
> `foundry v1.4.2` (`.tool-versions`).** They have not been revalidated on the pinned version, and
> `verify-bytecode`'s explorer handling has changed across releases. Treat the explorer-first order
> as the supported one rather than relying on any particular version tolerating an unverified
> contract, and re-run the commands on the pinned toolchain if you need that guarantee.

Note that the L1 implementations will show as `Bridge` and `ERC20Vault`, not `MainnetBridge` and
`MainnetERC20Vault` — see Current State for why that rename is expected.

### The fill-in commit

Once the three vault-side addresses exist:

1. Set `ERC20_VAULT_NEW_IMPL_L1`, `ERC20_VAULT_NEW_IMPL_L2` and `BRIDGED_ERC20_NEW_IMPL_L2` in
   `Proposal0023.s.sol` from the logged addresses, and add codediff links for the two vault proxies
   next to the bridge ones.
2. **Replace — do not delete — `test_placeholderConstantsStillGuardTheBuilders`** in
   `Proposal0023.t.sol`. While the constants are zero that test is the only thing proving the
   no-argument builders refuse to encode them; its replacement should assert that the no-argument
   builders return what the parameterised builders return for the deployed addresses, written as
   literals. The `L1Deployment`/`L2Deployment` structs have named fields, so the transposed-forward
   hazard the bridge-only version of this test guarded against no longer exists.
3. Regenerate the calldata with `P=0023 pnpm proposal` and commit `Proposal0023.action.md`.
   `test_actionFileMatchesTheBuiltCalldata` skips while the file is absent and pins it once it
   exists.
4. Fill in the Deployed Addresses and pre-execution checklist placeholders below.

One step remains before submission. It broadcasts, so it needs a signer and is not part of any
commit:

```bash
cd packages/protocol
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
and then executes the seven L2 actions. Note what it does **not** cover — it calls
`DelegateController.dryrun` directly rather than delivering the batch through `processMessage`, so it
does not exercise the mid-call self-upgrade. Only `test/layer1/proposals/Proposal0023Fork.t.sol`
does that.

The generated `Proposal0023.action.md` should be formatted with the repo formatter (the pre-commit
hook does this automatically), or reviewers should compare only the calldata line. A second reviewer
should re-run `P=0023 pnpm proposal` independently and diff the result.

## Deployed Addresses

The bridge-side contracts were deployed 2026-09-01 and verified on-chain before being written in.
The codediff links show the live implementation against the new one for each proxy being upgraded.

The bridge implementations are a **redeployment**. #22082 landed comment-only changes to
`contracts/shared/bridge/Bridge.sol` after the first set was deployed; comments feed the solc
metadata hash, so the runtime bytecode changed and the original implementations no longer
corresponded to `main`. The addresses here are built from this branch's post-#22082 `main`. Nothing
about the proposal's actions or arguments changed — only the addresses they point at.

| What                                | Address                                      |                                                                                                                                                           |
| ----------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1 `Bridge` implementation          | `0xA15dca0A72da684f20e0FC708DECFb230a715462` | [codediff](https://codediff.taiko.xyz/?addr=0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC&newimpl=0xA15dca0A72da684f20e0FC708DECFb230a715462&chainid=1)      |
| L1 `ERC20Vault` implementation      | _pending_                                    | codediff against `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` on chain 1                                                                                  |
| L2 `Bridge` implementation          | `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` | [codediff](https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000001&newimpl=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&chainid=167000) |
| L2 `ERC20Vault` implementation      | _pending_                                    | codediff against `0x1670000000000000000000000000000000000002` on chain 167000                                                                             |
| L2 `BridgedERC20` implementation    | _pending_                                    | new contract, nothing to diff; registered as `bridged_erc20`, not a proxy target                                                                          |
| L2 `DefaultResolver` proxy          | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | new proxy, nothing to diff                                                                                                                                |
| L2 `DefaultResolver` implementation | `0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a` | new contract, nothing to diff                                                                                                                             |

The four bridge-side contracts are verified on their explorers as of 2026-09-01 — `Bridge`,
`Bridge`, `ERC1967Proxy` and `DefaultResolver` respectively, each under `solc v0.8.30`, optimizer on
at 200 runs, `evm_version` `osaka`. The L1 entry reads `Bridge`, not `MainnetBridge` — see Current
State.

`forge verify-bytecode` was re-run against the bridge-side redeployment on 2026-09-01, from a build
of this commit:

| Contract                            | Creation code | Runtime code            |
| ----------------------------------- | ------------- | ----------------------- |
| L1 `Bridge` implementation          | `status full` | `status full`           |
| L2 `Bridge` implementation          | `status full` | not reached — see below |
| L2 `DefaultResolver` implementation | `status full` | not reached — see below |

The two L2 runs matched their creation code and then aborted before the runtime comparison with
`foundry config error: invalid type: found string "taiko", expected u64` — foundry resolves chain
167000 to the named alias and then fails to read that alias back as the numeric chain id it
expects. That is a tooling limitation on Taiko L2, not a discrepancy in the contracts, and it is
as far as that check goes today. A full creation-code match is the substantive result in any case:
runtime code is what executing that creation code produces, and the immutables it patches in are
separately read back below.

The L2 `DefaultResolver` proxy is not covered by `forge verify-bytecode` here. It is an unmodified
OpenZeppelin `ERC1967Proxy`; what pins it is that its EIP-1967 implementation slot points at the
`DefaultResolver` implementation above, which did match, and that its `owner()` is the
DelegateController.

What has been checked on-chain for the four bridge-side addresses: code sizes are 14,913 / 14,913 /
170 / 4,504 bytes; the L1 implementation's four immutables equal the live L1 proxy's; the L2
implementation's `resolver()` is the new proxy with `quotaManager()` and `pauser()` both zero; the
proxy's EIP-1967 slot points at the `DefaultResolver` implementation listed above; its `owner()` is
the DelegateController; and it holds no registrations yet, since registering is L2 actions 0 to 4.

The L1 codediffs carry the proposal's whole argument: the bridge one should show only
`_SEND_ETHER_GAS_LIMIT` rising from 35,000 to 135,000 plus the `MainnetBridge` → `Bridge` folding
that #22058 performed at byte-identical slot constants; the vault one should show only #22093's
permit and Permit2 entrypoints plus the same `MainnetERC20Vault` → `ERC20Vault` folding. The L2
codediffs are necessarily large — they span the protocol 1.10.0 implementations from October 2024 to
`main`, which is what Current State and Upgrade Safety exist to explain.

> **Read the L2 addresses on L2 only.** All three bridge-side L2 addresses collide with historical
> **L1** implementations retired in 2024 — `0x2dfef033…` and `0x4F750D13…` and `0x097BBBef…` appear
> in `deployments/mainnet-contract-logs-L1.md` as former `erc721_vault`, `erc20_vault` and
> `erc1155_vault` implementations. They are unrelated contracts that share addresses because the
> same deployer reached the same nonces on both chains; the L1 and L2 code at each address differs.
> Confirmed: `0x097BBBef…` is 14,913 bytes on L2 and 17,997 on L1. Expect the same of the vault-side
> L2 addresses once deployed.

## Verification

### Before execution

Every commented value is the expected result. Replace the three `<…_NEW_IMPL_…>` placeholders once
the vault-side contracts are deployed.

```bash
export L1_RPC=<l1 rpc>
export L2_RPC=https://rpc.mainnet.taiko.xyz

# L1 bridge implementation immutables — all four must equal the live proxy's.
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "signalService()(address)" --rpc-url $L1_RPC  # 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "pauser()(address)"        --rpc-url $L1_RPC  # 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F

# L1 vault implementation immutables — both must equal the live proxy's.
cast call <ERC20_VAULT_NEW_IMPL_L1> "resolver()(address)"     --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call <ERC20_VAULT_NEW_IMPL_L1> "quotaManager()(address)" --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call <ERC20_VAULT_NEW_IMPL_L1> "PERMIT2()(address)"      --rpc-url $L1_RPC  # 0x000000000022D473030F116dDEE9F6B43aC78BA3

# L2 bridge implementation immutables. `resolver()` is the load-bearing one — see the note below.
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "signalService()(address)" --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000005
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "pauser()(address)"        --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000

# L2 vault implementation immutables, and the bridged-token implementation's.
cast call <ERC20_VAULT_NEW_IMPL_L2> "resolver()(address)"       --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984
cast call <ERC20_VAULT_NEW_IMPL_L2> "quotaManager()(address)"   --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call <ERC20_VAULT_NEW_IMPL_L2> "PERMIT2()(address)"        --rpc-url $L2_RPC  # 0x000000000022D473030F116dDEE9F6B43aC78BA3
cast call <BRIDGED_ERC20_NEW_IMPL_L2> "erc20Vault()(address)"   --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000002

# Permit2 is a constant in the vault, so it must actually exist on both chains.
cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url $L1_RPC | wc -c  # 18307 (non-empty)
cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url $L2_RPC | wc -c  # 18307 (non-empty)

# The resolver is a proxy the DAO will call registerAddress on. owner() says who controls it;
# the EIP-1967 slot says what code runs.
cast call    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "owner()(address)" --rpc-url $L2_RPC  # 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C
cast storage 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L2_RPC  # 0x8Af4669E…07a9a

# Both vault proxies are owned by the controller that will call upgradeTo on them.
cast call 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab "owner()(address)" --rpc-url $L1_RPC  # 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
cast call 0x1670000000000000000000000000000000000002 "owner()(address)" --rpc-url $L2_RPC  # 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C

# Authenticate the code, not just the getters. A substituted contract can answer every getter
# above while carrying different logic. ETHERSCAN_API_KEY is required — one Etherscan V2 key
# covers both chains.
export ETHERSCAN_API_KEY=<key>

FOUNDRY_PROFILE=layer1 forge verify-bytecode 0xA15dca0A72da684f20e0FC708DECFb230a715462 \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C \
    0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F)

FOUNDRY_PROFILE=layer1 forge verify-bytecode <ERC20_VAULT_NEW_IMPL_L1> \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC)

# First argument is the resolver PROXY, not its implementation.
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x1670000000000000000000000000000000000005 \
    0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000)

FOUNDRY_PROFILE=layer2 forge verify-bytecode <ERC20_VAULT_NEW_IMPL_L2> \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x0000000000000000000000000000000000000000)

FOUNDRY_PROFILE=layer2 forge verify-bytecode <BRIDGED_ERC20_NEW_IMPL_L2> \
  contracts/shared/vault/BridgedERC20.sol:BridgedERC20 --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x1670000000000000000000000000000000000002)

FOUNDRY_PROFILE=layer2 forge verify-bytecode 0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a \
  contracts/shared/common/DefaultResolver.sol:DefaultResolver --rpc-url $L2_RPC

FOUNDRY_PROFILE=layer2 forge verify-bytecode 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 \
  ERC1967Proxy --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,bytes)" 0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a \
    $(cast calldata "init(address)" 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C))

# Rehearse the exact batch against live state; both legs must pass.
L1_FORK_URL=$L1_RPC L2_FORK_URL=$L2_RPC FOUNDRY_PROFILE=layer1 \
  forge test --match-contract Proposal0023ForkTest -vv
```

**The pass signal is `Creation code matched with status full`** — it proves the deployed creation
code, constructor arguments included, is what a local build of this commit produces.

Notes, in the order you will trip over them:

- Use `--encoded-constructor-args`, not `--constructor-args`. The latter wants individual raw
  values and rejects a pre-encoded blob on the pinned `forge v1.4.2`.
- Do not add `--chain <id>`; the chain comes from `--rpc-url`. Passing it makes foundry resolve the
  id to a named chain and then reject its own value.
- The runtime phase after the creation match needs an archive node, and public endpoints refuse it.
  Stopping at the creation-code match is fine.
- `cast codehash` is not a substitute. `Bridge` has five immutables at 25 patch sites, one being
  OpenZeppelin `UUPSUpgradeable`'s `__self = address(this)`, and `ERC20Vault` and `BridgedERC20`
  carry the same `__self`, so identical code at different addresses hashes differently and no
  expected hash can be published.

**Why the L2 `resolver()` reads matter more than the others.** All deploy scripts self-check their
immutables, but during _simulation_. `DeployBridgeUpgradeL2` deploys the resolver proxy and passes
its address into the `Bridge` constructor, so if the deployer's nonce differs at broadcast time the
`CREATE` addresses shift while the already-built `Bridge` creation calldata keeps the simulated
address — leaving an implementation whose `resolver` immutable points at nothing, which the script
cannot catch. `DeployERC20VaultUpgradeL2` avoids that class of problem by taking the resolver as a
constant that already exists on-chain, but its `erc20Vault()` and `resolver()` reads above are what
prove the constant was the right one. The L1 immutables are all library constants and cannot dangle
this way.
