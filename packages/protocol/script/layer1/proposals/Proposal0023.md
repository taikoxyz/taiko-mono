# PROPOSAL-0023: Upgrade the L1 and L2 Bridges and ERC20 Vaults

## Executive Summary

Proposal0023 ships two merged changes to production by upgrading four proxies, two per chain. No
contract source changes ship with it — deploy scripts, the DAO proposal, this runbook and tests
only.

- **Bridges.** [PR #22077](https://github.com/taikoxyz/taiko-mono/pull/22077) raised
  `Bridge._SEND_ETHER_GAS_LIMIT` from 35,000 to 135,000 gas, the `CALL` gas operand for every Ether
  send to a message recipient. Under EIP-8037 (Glamsterdam) creating one fresh storage slot costs
  97,920 gas out of the callee's own budget, so a smart wallet that writes a single slot on its
  receive path would run out of gas under the old cap, and because a failed send reverts message
  processing its inbound messages would become permanently unclaimable. The new cap is
  35,000 + 97,920, rounded up.
- **ERC20 vaults.** [PR #22093](https://github.com/taikoxyz/taiko-mono/pull/22093) added
  `sendTokenWithPermit` (an EIP-2612 `permit`, so no separate `approve`) and `sendTokenWithPermit2`
  (Uniswap's Permit2 `0x000000000022D473030F116dDEE9F6B43aC78BA3`, deployed on both chains, so it
  works for every ERC20). Both are opt-in additions on the send path; `sendToken`, deliveries and
  recalls are unchanged.
- **The L1 `bridged_erc20`.** The L1 shared resolver still names the July 2024 `BridgedERC20`
  implementation, which the live L1 vault has been unable to initialise since Proposal0017, so the
  first delivery to L1 of a token canonical on another chain reverts today. The proposal registers
  a `BridgedERC20` built from `main`, the same fix the L2 leg needs anyway.

On L1 both legs are like-for-like redeploys. On L2 the bridge and the ERC20 vault both still run
protocol 1.10.0 implementations from October 2024, which predate the resolver refactor, so they
additionally need a resolver that speaks `IResolver` and, for the vault, a `BridgedERC20`
implementation built from `main`. [Why L2 Needs a New Resolver](#why-l2-needs-a-new-resolver)
covers both.

The proposal executes **4 top-level L1 actions** and **7 L2 actions**. All eight contracts it
points at are deployed and verified — the bridge-side four on 2026-08-31 (redeployed 2026-09-01
after #22082), the vault-side three and the L1 `BridgedERC20` on 2026-09-02 — and
`Proposal0023.action.md` carries the executable calldata.

## Scope

| Chain | Contract                                                                 | Change                                                                                                                                   |
| ----- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| L1    | Bridge proxy `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`                | implementation → `0xA15dca0A72da684f20e0FC708DECFb230a715462`                                                                            |
| L1    | ERC20Vault proxy `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`            | implementation → `0x32E47c04E8c329E8c10062731448e7658aDEEB8e`                                                                            |
| L1    | Shared resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`             | `bridged_erc20` → `0xFcbc02A2AdED1B9464B37369091279D297E20a96` for chain 1                                                               |
| L2    | Bridge proxy `0x1670000000000000000000000000000000000001`                | implementation → `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb`                                                                            |
| L2    | ERC20Vault proxy `0x1670000000000000000000000000000000000002`            | implementation → `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3`                                                                            |
| L2    | New `DefaultResolver` proxy `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | `bridge` and `erc20_vault` registered for chains 1 and 167000; `bridged_erc20` → `0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944` for 167000 |

Not touched: the L2 NFT vaults and the legacy L2 `AddressManager` `0x1670000000000000000000000000000000000006`,
which keeps serving them and every bridged token the 1.10.0 vault ever deployed; every other entry
of the L1 resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`, which both L1 upgrades reuse;
ownership (no `transferOwnership`, `acceptOwnership` or initializer call on any live contract); Hoodi
and every other network.

**Also fixed: the L1 `bridged_erc20`.** The L1 resolver's `bridged_erc20` is
`0x65666141a541423606365123Ed280AB16a09A2e1`, a July 2024 implementation with only the
seven-argument `init` (selector `0xbb86ef93`), while the live L1 vault has called the six-argument
`IBridgedERC20Initializable.init` (`0x6c0db62b`) since Proposal0017. So the first delivery to L1 of
a token canonical on another chain reverts today inside `_deployBridgedToken` — the same defect the
L2 leg would have without its new `BridgedERC20`, and the same fix: L1 action 3 registers a
`BridgedERC20` built from `main` with the L1 vault proxy as its `erc20Vault` immutable. Existing
L1 bridged tokens are untouched; only tokens deployed from now on use the new implementation. The
fork rehearsal delivers a never-seen token to L1 after the batch and asserts it mints from the new
implementation.

## Current State

Verified on-chain 2026-09-02.

|           | proxy                                        | owner                                                                                | live impl                                    | provenance                                    |
| --------- | -------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- | --------------------------------------------- |
| L1 bridge | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0x1c94D798CFA08F396E5BA9F81697289c53273381` | Proposal0017, 2026-06-29, commit `b73608696`  |
| L1 vault  | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | DAO controller                                                                       | `0x024253C6FDC27d3161aFd43fb0241411A28dDc3c` | Proposal0017, 2026-06-29, commit `b73608696`  |
| L2 bridge | `0x1670000000000000000000000000000000000001` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83` | protocol 1.10.0, 2024-10-31, commit `9345f14` |
| L2 vault  | `0x1670000000000000000000000000000000000002` | DelegateController                                                                   | `0xb96AbB41b01E3ad519D00E80355a1c3801910F62` | protocol 1.10.0, 2024-10-31, commit `9345f14` |

The live L1 implementations are a `MainnetBridge` and a `MainnetERC20Vault`, the L1-only subclasses
#22058 deleted; this proposal deploys the unified `Bridge` and `ERC20Vault`, which explorers show
under those names. The subclasses only moved the reentrancy lock (and the bridge's call context) to
transient storage, and #22058 folded both into the base contracts at byte-identical slot constants
(`_REENTRY_SLOT` `0xa5054f72…31d9721b`, `_CTX_SLOT` `0xe4ece821…dbadc2b9`), so the rename is not a
behavioural change. Diffing each implementation's dependency tree from `b73608696` to `main` leaves
`Bridge.sol` (the cap), `ERC20Vault.sol` with the new `IPermit2.sol` (the permit entrypoints),
`EssentialContract.sol` (that folding) and an unused `LibNames` constant.

The new implementations' immutables:

| Contract  | `resolver()`                                                 | `signalService()`                            | `quotaManager()`                             | `pauser()`                                                       |
| --------- | ------------------------------------------------------------ | -------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------- |
| L1 bridge | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` (unchanged)     | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` (`admin.taiko.eth`) |
| L1 vault  | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` (unchanged)     | —                                            | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | —                                                                |
| L2 bridge | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` (the new proxy) | `0x1670000000000000000000000000000000000005` | zero                                         | zero                                                             |
| L2 vault  | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` (the new proxy) | —                                            | zero                                         | —                                                                |

The L1 values equal the live proxies' (both L1 deploy scripts check that). The L2 zeros preserve
today's behaviour: `quota_manager`, `chain_watchdog` and `bridge_watchdog` are all unset on the
legacy L2 registry, so L2 has no quota and only the owner can pause. The 1.10.0 bridge has no
`receive()` and the new one's `receive()` admits only `pauser`, which no sender can be when it is
zero, so direct Ether transfers to the L2 bridge keep reverting exactly as today. The new
`BridgedERC20`'s `erc20Vault` immutable is the vault proxy `0x1670000000000000000000000000000000000002`.

Preconditions to re-read at execution time: the L2 bridge must not be paused (`processMessage` is
`whenNotPaused`), and `DelegateController.lastExecutionId()` is `1`. The L2 bridge balance, about
999,998,918 ETH of premint float, is what the L2 leg puts at risk.

## Why L2 Needs a New Resolver

The L2 registry `0x1670000000000000000000000000000000000006` is the 1.10.0 `AddressManager`. It only
answers `getAddress(uint64,bytes32)`; `IResolver.resolve(uint256,bytes32,bool)`, which `Bridge` and
`ERC20Vault` on `main` call, reverts on it. Pointing either new implementation at it would revert
every `sendMessage`, `processMessage`, `sendToken` and delivery on L2. The fix mirrors what L1 did in
May 2025: a separate `DefaultResolver` for the contracts that receive new implementations, the NFT
vaults left on the legacy registry, and only the names the migrated contracts read registered.

| Registration                  | Read by                                                                                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bridge`, chain 1             | the bridge, on every send, recall and claim: all three of its lookups (`Bridge.sol:491`, `:607`, `:658`) pass the counterparty id                                                                      |
| `bridge`, chain 167000        | the vault's `onlyFromNamed(B_BRIDGE)` on every delivery and recall (`BaseVault.sol:56`, `ERC20Vault.sol:482`) and the bridge it sends through (`ERC20Vault.sol:424`); the bridge itself never reads it |
| `erc20_vault`, chain 1        | the vault: a delivery must come from it (`BaseVault.sol:60`), a send goes to it (`ERC20Vault.sol:415`), and it is the forbidden recipient (`BaseVault.sol:69`)                                         |
| `erc20_vault`, chain 167000   | nothing today; symmetry with the L1 resolver, which carries its own chain's entry                                                                                                                      |
| `bridged_erc20`, chain 167000 | the vault, on the first delivery of a canonical token it has not seen before (`ERC20Vault.sol:664`)                                                                                                    |

**`bridged_erc20` must be a `BridgedERC20` built from `main`, not the legacy
`0x98161D67f762A9E589E502348579FA38B1Ac47A8`.** `ERC20Vault._deployBridgedToken` creates each bridged
token as `new ERC1967Proxy(resolve("bridged_erc20"), init)` with the six-argument
`IBridgedERC20Initializable.init` (`0x6c0db62b`). The legacy implementation's bytecode carries only
the seven-argument init (`0xbb86ef93`) and no fallback, so the proxy constructor's delegatecall
would revert and the bridge would park every first-time token delivery as `RETRIABLE`; even with a
matching initializer it would authorise `mint`/`burn` through `IAddressManager.getAddress`, which
`DefaultResolver` does not have. `BridgedERC20` on `main` takes the vault as a constructor immutable
instead, and `0x3505a070…` was deployed with the vault proxy, so tokens deployed after this proposal
survive future vault upgrades too. Existing bridged tokens keep working the other way round: they
resolve `erc20_vault` through the legacy registry, which still names the unchanged proxy. L1 has
the same mismatch today — its resolver names the same July 2024 lineage — which is why L1 action 3
registers a `BridgedERC20` built from `main` there as well.

## Upgrade Safety

### Storage layout

Slot boundaries are identical between the 1.10.0 lineage and `main` for both contracts
(`forge inspect … storage-layout` at `9345f14` against the `*_Layout.sol` files on `main`):

| slot          | 1.10.0                                                                                                   | `main`                               |
| ------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| 151           | `AddressResolver.addressManager`                                                                         | `__gapFromOldAddressResolver[0]`     |
| 152–200       | `AddressResolver.__gap[49]`                                                                              | `__gapFromOldAddressResolver[1..49]` |
| 201.0 / 201.1 | `__reentry` / `__paused`                                                                                 | identical                            |
| 201.2         | `lastUnpausedAt` (uint64)                                                                                | unused                               |
| 202–250       | `__gap[49]`                                                                                              | identical                            |
| 251–300       | bridge: `nextMessageId`, `messageStatus`, `__ctx`, reserved slots, `__gap`; vault: `BaseVault.__gap[50]` | identical                            |
| 301–350       | vault: `bridgedToCanonical`, `canonicalToBridged`, `btokenDenylist`, `lastMigrationStart`, `__gap[46]`   | identical                            |

`lastUnpausedAt` was dropped, leaving stale bytes nothing reads; `addressManager` is absorbed by the
gap that exists for exactly this reason. The L1 bridge and vault already made this exact jump in
Proposal0017, and the vault has custodied mainnet deposits on that layout since.

### ABI

The vault's `BridgeTransferOp` struct, its five events and its errors are identical between 1.10.0
and `main`; `main` adds `sendTokenWithPermit`, `sendTokenWithPermit2`, `VAULT_PERMIT_NO_ALLOWANCE`
and `PERMIT2`, and drops the second parameter of `init`, which nothing live calls. The relayer, the
indexer and the bridge UI are unaffected.

### What else changes on L2

The L2 codediffs span two years, so the differences a user or relayer can observe were enumerated
from `git diff 9345f14 main` of `Bridge.sol` and `ERC20Vault.sol` rather than assumed:

- **The send cap**, `_SEND_ETHER_GAS_LIMIT` 35,000 → 135,000 (#22077), the point of the proposal.
- **Calldata to a recipient without code — the one change that touches messages already in
  flight.** The legacy `_unableToInvokeMessageCall` refuses calldata that is not
  `onMessageInvocation` only when `to` has code, so such a message to an EOA is delivered to `to`
  together with its value. `main` refuses it regardless of `to` (`Bridge.sol:699`, #20939, audit
  finding L-4: with EIP-7702 an EOA can carry code, so the distinction was unreliable) and refunds
  value and fee to `destOwner` as `INVOCATION_PROHIBITED`, in `processMessage` and `retryMessage`
  alike. The message still completes as `DONE`; only the recipient differs, and only when
  `destOwner != to`. An L1→L2 message sent before execution and claimed after it takes the new
  path. L1 made this exact transition in Proposal0017 on 2026-06-29. The fork rehearsal pins both
  sides (`_deliverToEoaWithCalldata` in `Proposal0023Fork.t.sol`): the 1.10.0 bridge delivers 1 ETH
  to the EOA, the upgraded bridge refunds it to `destOwner`.

  Outstanding messages were audited on 2026-09-02: every `MessageSent` of the L1 bridge from its
  deployment block 19,773,963 to L1 block 25,889,001 was decoded and filtered to
  `destChainId = 167000` with `data` of at least 4 bytes and a selector other than `0x7f07c947`,
  and each match was checked on L2 for code at `to` and for a `messageStatus` still `NEW` or
  `RETRIABLE`. Of the 40,494 messages, 20 carry such calldata; 19 of those target contracts, which both implementations refuse alike, and the one to a code-less address (block 20,029,081, `destOwner == to`) was delivered long ago. No outstanding message matches, so nothing in flight changes hands at execution. Re-run the same query right before execution; messages can be sent
  until then.

- **`sendMessage` rejects `to == address(0)`** (`nonZeroAddr(_message.to)`). The legacy bridge
  accepted such messages and refunded them on delivery. New sends only.
- **`selfDelegate(token)` is gone and `init3(bytes32[])` is new.** The former let anyone make the
  bridge delegate an ERC20Votes token's voting power to itself; the latter is the owner-only
  `reinitializer(3)` Proposal0017 used on L1 to force-mark message hashes `DONE`. Neither is used
  here.
- **The vault checks the recipient at send time.** `sendToken` now rejects a zero recipient or the
  destination-chain vault (`checkToAddressOnSrcChain`); 1.10.0 only rejected a zero or self
  recipient at delivery, which `main` still does.
- **Unchanged:** the `Message` struct and `hashMessage`, so every in-flight message keeps its hash
  and its signal; `getMessageMinGasLimit` and the fee math; the events; quota (none on L2 before
  or after); who can pause (the owner). The vault keeps its struct, events and errors, gains the two
  permit entrypoints, and deploys new bridged tokens from `0x3505a070…` as described above; its
  delivery and recall semantics are unchanged.

### The L2 bridge upgrades itself mid-call

The L2 bridge proxy is owned by the DelegateController, reachable only through a bridged message the
L2 bridge itself processes, so `upgradeTo` on it executes inside the bridge's own `processMessage`
frame while that frame's reentrancy lock is held. Each step was checked:

1. `_authorizeUpgrade` is `onlyOwner` with no `nonReentrant` in both the 1.10.0 and the `main`
   `EssentialContract`.
2. `DelegateController.onMessageInvocation` reads `IBridge(msg.sender).context()` before
   `_executeActions`, against the old implementation's populated storage context.
3. After the swap the new implementation reads its lock from transient storage; a fresh slot reads
   `0`, which `_checkReentrancy()` accepts. The stale storage `__reentry` is never read again.
4. The old frame's remaining writes — `messageStatus` (slot 252), the context slots (253–254), the
   `nonReentrant` epilogue on 201 — land on slots the new layout agrees with, and it makes no call
   back into the proxy. The message carries `value: 0` and `fee: 0`, so there is no refund path.

The vault upgrade is a plain owner upgrade — the vault is not on the call stack — and is ordered
before the bridge swap so the batch makes no further call once the bridge's code has changed under
its frame. `test/layer1/proposals/Proposal0023Fork.t.sol` rehearses both legs against live state;
see [Verification](#verification).

### EVM version

`foundry.toml` pins `evm_version = "osaka"` for `profile.layer2` and `profile.shared`, so
`TSTORE`/`TLOAD` are available on L2.

## Action Order

### L1 — 4 top-level actions

1. `upgradeTo(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, 0xA15dca0A72da684f20e0FC708DECFb230a715462)` — the mainnet bridge.
2. `upgradeTo(0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, 0x32E47c04E8c329E8c10062731448e7658aDEEB8e)` — the mainnet ERC20 vault.
3. `0x8Efa01564425692d0a0838DC10E300BD310Cb43e.registerAddress(1, LibNames.B_BRIDGED_ERC20, 0xFcbc02A2AdED1B9464B37369091279D297E20a96)`
   — the L1 `bridged_erc20` fix. Independent of the two upgrades, so its position does not matter.
4. `sendMessage(...)` on `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` — carries the L2 batch to the
   DelegateController. Not written in `Proposal0023.s.sol`: `BuildProposal._buildAllActions()`
   appends it whenever `buildL2Actions()` is non-empty, with `value: 0`, zero fee,
   `gasLimit = 5_000_000`, `srcOwner` = the DAO controller, `to` = the DelegateController
   `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` and `destOwner` = `PERMISSIONLESS_EXECUTOR`
   `0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA`, so anyone can relay it.

The message is sent through the just-upgraded bridge, so the new implementation's `sendMessage`
runs `isDestChainEnabled(167000)` against the L1 resolver in the same transaction it goes live. The
L1 dry run and the fork rehearsal both prove that against live state.

### L2 — 7 actions, `l2ExecutionId = 0`, `l2GasLimit = 5_000_000`

Numbered from 1 here, `actions[0]` to `actions[6]` in `Proposal0023.s.sol`. The registrations are
on the new resolver `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984`, with names encoded from
`LibNames` constants.

1. `registerAddress(1, "bridge", 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC)`
2. `registerAddress(167000, "bridge", 0x1670000000000000000000000000000000000001)`
3. `registerAddress(1, "erc20_vault", 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab)`
4. `registerAddress(167000, "erc20_vault", 0x1670000000000000000000000000000000000002)`
5. `registerAddress(167000, "bridged_erc20", 0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944)`
6. `upgradeTo(0x1670000000000000000000000000000000000002, 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3)` — the vault.
7. `upgradeTo(0x1670000000000000000000000000000000000001, 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb)` — the bridge's
   mid-call self-upgrade, deliberately last.

All seven execute in one transaction, so the order inside the batch is defensive; what matters is
that the registrations and the upgrades ship together. An upgrade landing without its registrations
would leave L2 reverting every bridge and vault call until they did.

Parameter choices: `l2ExecutionId = 0` is the unordered mode Proposal0007 and Proposal0011 used
(the ordered value would be `2`, and would break if another L2 proposal executed first).
`l2GasLimit = 5_000_000` matches Proposal0011; after the 1.10.0 bridge deducts `GAS_RESERVE`
(800,000) and the calldata charge (39,936 for this 2,052-byte message), a relayer-driven invocation
gets 4,160,064 gas, more than ten times what the seven actions need, and the fork test's relayer
case pins that budget. The resolver was initialised with the DelegateController as owner at deploy
time so that the registrations are proposal actions, auditable in the DAO calldata, rather than
deploy-time calls plus an `acceptOwnership`.

## Deployment

Bridge side, run on 2026-08-31. `DeployBridgeUpgradeL1` logs `BRIDGE_NEW_IMPL_L1`;
`DeployBridgeUpgradeL2` logs `L2_SHARED_RESOLVER`, its implementation and `BRIDGE_NEW_IMPL_L2`.

```bash
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployBridgeUpgradeL1.s.sol:DeployBridgeUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast
```

```bash
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/mainnet/DeployBridgeUpgradeL2.s.sol:DeployBridgeUpgradeL2 \
  --rpc-url https://rpc.mainnet.taiko.xyz --broadcast
```

Vault side, run on 2026-09-02 with `--verify`. `DeployERC20VaultUpgradeL1` checks the live proxy's
immutables against `LibL1Addrs` before broadcasting and logs `ERC20_VAULT_NEW_IMPL_L1`;
`DeployERC20VaultUpgradeL2` checks that the resolver is owned by the DelegateController and logs
`BRIDGED_ERC20_NEW_IMPL_L2` and `ERC20_VAULT_NEW_IMPL_L2`.

```bash
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployERC20VaultUpgradeL1.s.sol:DeployERC20VaultUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast
```

```bash
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
  script/layer2/mainnet/DeployERC20VaultUpgradeL2.s.sol:DeployERC20VaultUpgradeL2 \
  --rpc-url https://rpc.mainnet.taiko.xyz --broadcast
```

L1 `bridged_erc20`, run on 2026-09-02 with `--verify`. `DeployBridgedERC20L1` deploys a
`BridgedERC20` with the L1 vault proxy as its immutable and logs `BRIDGED_ERC20_NEW_IMPL_L1`; the
registration itself is L1 action 3, because the resolver is owned by the DAO controller.

```bash
PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployBridgedERC20L1.s.sol:DeployBridgedERC20L1 \
  --rpc-url <L1_RPC> --broadcast
```

All five scripts deploy only — no proxy upgrade, no initializer call on a live contract — and none
should be re-run: a second run deploys contracts the constants do not point at. The logged
addresses were verified on-chain before being written into `Proposal0023.s.sol`, the calldata was
regenerated with `P=0023 pnpm proposal`, and both dry runs were simulated against the deployment
RPCs:

```bash
cd packages/protocol
MODE=l1dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0023.s.sol:Proposal0023 --rpc-url <L1_RPC>
MODE=l2dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0023.s.sol:Proposal0023 --rpc-url https://rpc.mainnet.taiko.xyz
```

Both revert with `DryrunSucceeded()`, which is the success signal. `Controller.dryrun` is
permissionless and always reverts, so the `--broadcast` in the `pnpm proposal:dryrun:*` scripts can
never send anything; the simulation is the whole check. The L2 dry run calls
`DelegateController.dryrun` directly and so does not exercise the mid-call self-upgrade; only the
fork test does. A second reviewer should re-run `P=0023 pnpm proposal` and diff
`Proposal0023.action.md`; `test_actionFileMatchesTheBuiltCalldata` pins it in CI.

## Deployed Addresses

| What                                | Address                                      |                                                                                       |
| ----------------------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------- |
| L1 `Bridge` implementation          | `0xA15dca0A72da684f20e0FC708DECFb230a715462` | proxy upgrade; codediff in the table below                                            |
| L1 `ERC20Vault` implementation      | `0x32E47c04E8c329E8c10062731448e7658aDEEB8e` | proxy upgrade; codediff in the table below                                            |
| L1 `BridgedERC20` implementation    | `0xFcbc02A2AdED1B9464B37369091279D297E20a96` | registered as `bridged_erc20` on the L1 resolver, not a proxy target; nothing to diff |
| L2 `Bridge` implementation          | `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` | proxy upgrade; codediff in the table below                                            |
| L2 `ERC20Vault` implementation      | `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3` | proxy upgrade; codediff in the table below                                            |
| L2 `BridgedERC20` implementation    | `0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944` | registered as `bridged_erc20`, not a proxy target; nothing to diff                    |
| L2 `DefaultResolver` proxy          | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | new proxy, nothing to diff                                                            |
| L2 `DefaultResolver` implementation | `0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a` | new contract, nothing to diff                                                         |

Codediff of each proxy upgrade, the live implementation against the new one:

| Contract      | codediff                                                                                                                                      |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| L1 Bridge     | https://codediff.taiko.xyz/?addr=0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC&newimpl=0xA15dca0A72da684f20e0FC708DECFb230a715462&chainid=1      |
| L1 ERC20Vault | https://codediff.taiko.xyz/?addr=0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab&newimpl=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&chainid=1      |
| L2 Bridge     | https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000001&newimpl=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&chainid=167000 |
| L2 ERC20Vault | https://codediff.taiko.xyz/?addr=0x1670000000000000000000000000000000000002&newimpl=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&chainid=167000 |

Vault-side creation transactions, all from deployer `0x56706f118e42ae069f20c5636141b844d1324ae1`:

| Contract                         | Chain  | Block      | Transaction                                                          |
| -------------------------------- | ------ | ---------- | -------------------------------------------------------------------- |
| L1 `ERC20Vault` implementation   | 1      | 25,888,605 | `0x83c8f81f1241428453e25e04e32539136bb9db3e1c148f8892a2559b0e53057e` |
| L1 `BridgedERC20` implementation | 1      | 25,889,196 | `0x758d9b70f5e2dfb03b4730e56002199631ced14fe52055bf347958e90f28c8ad` |
| L2 `BridgedERC20` implementation | 167000 | 10,865,570 | `0xa40d7656f405988c26aa9c1e1754c09c9f04605cc94b46fb0e2bd5f612781ca4` |
| L2 `ERC20Vault` implementation   | 167000 | 10,865,570 | `0x00371d3b209576df1ce447011477f0c27b816e12c123a207588790644dbc10b3` |

All eight are verified on their explorers under `solc v0.8.30`, optimizer at 200 runs,
`evm_version` `osaka`; the L1 entries read `Bridge` and `ERC20Vault`, not `Mainnet*`.
`forge verify-bytecode` from a build of this branch matches creation code with `status full` for all
seven implementations, and runtime code for all but the two bridge-side L2 runs, which aborted after
the creation match on a foundry chain-alias error (`found string "taiko", expected u64`). The
creation-code match is the substantive result, and the immutables are read back in Verification.
The resolver proxy is an unmodified OpenZeppelin `ERC1967Proxy`, pinned by its implementation slot
and its `owner()`.

The bridge implementations are a redeployment: #22082 changed comments in `Bridge.sol` after the
first set was deployed, and comments feed the metadata hash. The L1 codediffs carry the proposal's
argument — the bridge one should show only the cap plus the `MainnetBridge` → `Bridge` folding, the
vault one only #22093 plus the `MainnetERC20Vault` → `ERC20Vault` folding — while the L2 codediffs
span 1.10.0 to `main`, which is what Current State and Upgrade Safety exist to explain.

> **Read the L2 addresses on L2 only.** Every one of them has, or collides with, unrelated code on
> L1 — the bridge-side ones with vault implementations retired in 2024, `0x3505a070…` with a
> 23,901-byte contract, `0xa01d464c…` with a 170-byte proxy — because the same deployer reached the
> same nonces on both chains.

## Verification

Every commented value is the expected result.

```bash
export L1_RPC=<l1 rpc>
export L2_RPC=https://rpc.mainnet.taiko.xyz

# New implementations' immutables; the L1 ones must equal the live proxies'.
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "signalService()(address)" --rpc-url $L1_RPC  # 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call 0xA15dca0A72da684f20e0FC708DECFb230a715462 "pauser()(address)"        --rpc-url $L1_RPC  # 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F
cast call 0x32E47c04E8c329E8c10062731448e7658aDEEB8e "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call 0x32E47c04E8c329E8c10062731448e7658aDEEB8e "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call 0x32E47c04E8c329E8c10062731448e7658aDEEB8e "PERMIT2()(address)"       --rpc-url $L1_RPC  # 0x000000000022D473030F116dDEE9F6B43aC78BA3
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "signalService()(address)" --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000005
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb "pauser()(address)"        --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3 "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984
cast call 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3 "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3 "PERMIT2()(address)"       --rpc-url $L2_RPC  # 0x000000000022D473030F116dDEE9F6B43aC78BA3
cast call 0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944 "erc20Vault()(address)"    --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000002
cast call 0xFcbc02A2AdED1B9464B37369091279D297E20a96 "erc20Vault()(address)"                       --rpc-url $L1_RPC  # 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab

# Permit2 is a constant in the vault, so it must exist on both chains.
cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url $L1_RPC | wc -c  # 18307
cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url $L2_RPC | wc -c  # 18307

# The resolvers the DAO registers on: who controls them, and what code runs. Both vault proxies
# are owned by the controller that will call upgradeTo on them.
cast call    0x8Efa01564425692d0a0838DC10E300BD310Cb43e "owner()(address)" --rpc-url $L1_RPC  # 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
cast call    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "owner()(address)" --rpc-url $L2_RPC  # 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C
cast storage 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L2_RPC  # 0x8Af4669E…07a9a
cast call 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab "owner()(address)" --rpc-url $L1_RPC  # 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
cast call 0x1670000000000000000000000000000000000002 "owner()(address)" --rpc-url $L2_RPC  # 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C

# Authenticate the code, not just the getters. Pass signal: "Creation code matched with status full".
# ETHERSCAN_API_KEY is required; one Etherscan V2 key covers both chains.
export ETHERSCAN_API_KEY=<key>
FOUNDRY_PROFILE=layer1 forge verify-bytecode 0xA15dca0A72da684f20e0FC708DECFb230a715462 \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C \
    0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F)
FOUNDRY_PROFILE=layer1 forge verify-bytecode 0x32E47c04E8c329E8c10062731448e7658aDEEB8e \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC)
FOUNDRY_PROFILE=layer1 forge verify-bytecode 0xFcbc02A2AdED1B9464B37369091279D297E20a96 \
  contracts/shared/vault/BridgedERC20.sol:BridgedERC20 --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab)
# First argument of the L2 bridge and vault is the resolver PROXY, not its implementation.
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x1670000000000000000000000000000000000005 \
    0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000)
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3 \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x0000000000000000000000000000000000000000)
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0x3505a0700DB72dEc7AbFF1aF231BB5D87aBF2944 \
  contracts/shared/vault/BridgedERC20.sol:BridgedERC20 --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x1670000000000000000000000000000000000002)
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a \
  contracts/shared/common/DefaultResolver.sol:DefaultResolver --rpc-url $L2_RPC
FOUNDRY_PROFILE=layer2 forge verify-bytecode 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 \
  ERC1967Proxy --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,bytes)" 0x8Af4669E3068Bae96b92cD73603f5D86beD07a9a \
    $(cast calldata "init(address)" 0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C))

# Rehearse the exact batch against live state; both legs must pass. Deploys nothing: it executes
# the committed calldata against the deployed implementations, then bridges tokens through the
# upgraded contracts (WETH out and a never-seen token in on L1; on L2, USDT in, a never-seen token
# in, bridged USDT out).
L1_FORK_URL=$L1_RPC L2_FORK_URL=$L2_RPC FOUNDRY_PROFILE=layer1 \
  forge test --match-contract Proposal0023ForkTest -vv
```

Notes: use `--encoded-constructor-args`, not `--constructor-args`, which rejects a pre-encoded blob
on the pinned `forge v1.4.2`; do not pass `--chain`, the chain comes from `--rpc-url`; the runtime
phase of `verify-bytecode` needs historical state and may abort after the creation match on an
endpoint without it. The results above were measured on `forge 1.5.1`, not the pinned `1.4.2`.
`cast codehash` cannot substitute for any of this: every implementation carries OpenZeppelin
`UUPSUpgradeable`'s `__self = address(this)` immutable, so identical code at different addresses
hashes differently.
