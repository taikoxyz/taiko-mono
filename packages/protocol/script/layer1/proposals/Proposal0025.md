# PROPOSAL-0025: Disable Message Recalls and Move the NFT Vaults onto the Shared Resolvers

## Executive Summary

Proposal0025 upgrades the bridge and all three token vaults on both chains, eight proxies in
total, to implementations built from `main`. No contract source changes ship with it: deploy
scripts, the DAO proposal, this runbook and tests only. It does two things.

**1. It ships [PR #22156](https://github.com/taikoxyz/taiko-mono/pull/22156) to production**, on the
same four proxies Proposal0024 upgrades (the bridge and ERC20 vault on each chain).

- **The defect.** `Bridge.recallMessage` debited the Ether withdrawal quota for the recalled
  `value`, and `ERC20Vault.onMessageRecalled` debited the token quota for the refunded amount,
  which let anyone exhaust a shared quota at zero net cost: lock the quota's worth on L1, let the
  delivery fail on L2 (as `destOwner`, process it into a rejecting recipient or with too little
  gas, then `failMessage`), and recall it on L1. With the mainnet configuration of 250 ETH per
  24 hours, one such cycle drained the whole Ether quota, so every other user's `recallMessage`
  and every L2 → L1 `processMessage` reverted with `QM_OUT_OF_QUOTA` until enough quota had
  refilled, and the cycle could be repeated for as long as the attacker liked, at gas cost only.
  The token quotas (250 WETH, 250,000 USDC, 250,000 USDT, 10,000,000 TAIKO per 24 hours) were
  exposed the same way through the vault. Dropping the debit alone is not safe either: a recall is
  released by the same destination-chain failure proof as a delivery, and the source chain never
  learns that a message it sent was delivered, so under a forged failure proof (the June 2026
  exploit forged signal proofs) every past deposit could be recalled a second time, with only the
  quota in the way.
- **The fix.** Failing and recalling messages are switched off on both chains. The new bridges
  are built with `recallEnabled = false`: `failMessage` and `recallMessage` revert with
  `B_RECALL_DISABLED`, and a failed last-attempt `retryMessage` reverts with `B_RETRY_FAILED`
  instead of marking the message `FAILED`, so no message can enter `FAILED` or `RECALLED`. The
  quotas are still debited in `processMessage`, on a successful `retryMessage` and in
  `onMessageInvocation`, exactly where assets leave custody. The recall code stays in place behind
  the switch, without its quota debit.

**2. It moves the ERC721 and ERC1155 vaults off the legacy AddressManagers.** The four NFT vault
proxies still run protocol 1.10.0 implementations (`9345f14`) that resolve every name through the
legacy AddressManagers (L1 `0xEf9EaA1dd30a9AA1df01c36411b5F082aA65fBaa`, L2
`0x1670000000000000000000000000000000000006`). L1 moved its bridge and ERC20 vault onto the shared
resolver in May 2025 and Proposal0024 does the same on L2; this proposal brings the NFT vaults
along, so that afterwards no bridge or vault on either chain reads an AddressManager and all eight
proxies run the same `main` code. The new NFT vaults deploy each bridged token through a
five-argument `init` and the token authorises its vault through an immutable, so the proposal also
registers new `BridgedERC721` and `BridgedERC1155` implementations on both resolvers: the ones
registered today only implement the six-argument, AddressManager-based `init`.

The AddressManagers are not retired, and must not be changed: every bridged token the old vaults
deployed (ERC20 and NFT, such as bridged TAIKO `0xA9d23408b9bA935c230493c40C73824Df71A0975` on L2)
still authorises its vault through them, and they keep naming the unchanged vault proxies.

**This proposal executes after Proposal0024.** The bridge and ERC20 vault implementations it
replaces are the ones Proposal0024 installs (`0xA15dca0A…`, `0x32E47c04…`, `0xa200c226…`,
`0xa01d464c…`), all of which were built before #22156 and carry the defect, and every L2
implementation reads the resolver Proposal0024 populates. Were Proposal0024 to execute after this
one it would reinstall the defective code, so the DAO must sequence them: Proposal0024 first, then
Proposal0025.

The proposal executes **7 top-level L1 actions** and **10 L2 actions**. The twelve contracts are
**not deployed yet**; see [Deployment](#deployment).

## Scope

| Chain | Contract                                                        | Change                                                                                                    |
| ----- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| L1    | Bridge proxy `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`       | implementation → `[new-impl-placeholder]`                                                                 |
| L1    | ERC20Vault proxy `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab`   | implementation → `[new-impl-placeholder]`                                                                 |
| L1    | ERC721Vault proxy `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`  | implementation → `[new-impl-placeholder]`                                                                 |
| L1    | ERC1155Vault proxy `0xaf145913EA4a56BE22E120ED9C24589659881702` | implementation → `[new-impl-placeholder]`                                                                 |
| L1    | Shared resolver `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`    | `bridged_erc721`, `bridged_erc1155` (chain 1) → new implementations                                       |
| L2    | Bridge proxy `0x1670000000000000000000000000000000000001`       | implementation → `[new-impl-placeholder]`                                                                 |
| L2    | ERC20Vault proxy `0x1670000000000000000000000000000000000002`   | implementation → `[new-impl-placeholder]`                                                                 |
| L2    | ERC721Vault proxy `0x1670000000000000000000000000000000000003`  | implementation → `[new-impl-placeholder]`                                                                 |
| L2    | ERC1155Vault proxy `0x1670000000000000000000000000000000000004` | implementation → `[new-impl-placeholder]`                                                                 |
| L2    | Shared resolver `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984`    | `erc721_vault`, `erc1155_vault` (chains 1 and 167000), `bridged_erc721`, `bridged_erc1155` (chain 167000) |

Not touched: the `QuotaManager` `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` and its per-token
quotas; the legacy AddressManagers and every entry on them; every other resolver entry; ownership
(no `transferOwnership`, `acceptOwnership` or initializer call on any live contract); Hoodi and
every other network.

## Prerequisite: Proposal0024

Verified on-chain on 2026-09-22 (L1 block 26,031,706, L2 block 11,717,269) and again on 2026-09-23:
Proposal0024 has not executed. The L1 bridge and vault still run the Proposal0017 implementations
(`0x1c94D798…`, `0x024253C6…`), the L2 bridge and vault still run protocol 1.10.0
(`0x95ae2918…`, `0xb96AbB41…`), and the new L2 resolver `0x2ea05A9C…` is deployed but empty.

Proposal0025 assumes the state Proposal0024 leaves behind, and nothing else. Proposal0024 does not
touch the NFT vaults, so their rows are today's implementations:

|                  | proxy                                        | owner                                                                                | implementation this proposal replaces        |
| ---------------- | -------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- |
| L1 bridge        | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0xA15dca0A72da684f20e0FC708DECFb230a715462` |
| L1 ERC20 vault   | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | DAO controller                                                                       | `0x32E47c04E8c329E8c10062731448e7658aDEEB8e` |
| L1 ERC721 vault  | `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa` | DAO controller                                                                       | `0xA4C5c20aB33C96B1c281Dca37D03E23609274C49` |
| L1 ERC1155 vault | `0xaf145913EA4a56BE22E120ED9C24589659881702` | DAO controller                                                                       | `0x838ed469db456b67EB3b0B74D759Be4DA999b9c8` |
| L2 bridge        | `0x1670000000000000000000000000000000000001` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` |
| L2 ERC20 vault   | `0x1670000000000000000000000000000000000002` | DelegateController                                                                   | `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3` |
| L2 ERC721 vault  | `0x1670000000000000000000000000000000000003` | DelegateController                                                                   | `0xd532f20a4751156C566Da7745db95E7f80145B36` |
| L2 ERC1155 vault | `0x1670000000000000000000000000000000000004` | DelegateController                                                                   | `0xBBBC4ad39488b990E095042fa6c59A90d3817846` |

The new bridges and ERC20 vaults carry exactly the immutables of the implementations Proposal0024
installs, plus the bridges' new `recallEnabled`, `false` on both chains. The NFT vaults read the
chain's shared resolver and the bridged-token implementations bind to the chain's vault proxies.
Both deploy scripts check these before and after broadcasting:

| Contract          | `resolver()`                                 | `signalService()`                            | `quotaManager()`                             | `pauser()`                                                       | other                          |
| ----------------- | -------------------------------------------- | -------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------- | ------------------------------ |
| L1 bridge         | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` (`admin.taiko.eth`) | `recallEnabled()` `false`      |
| L1 ERC20 vault    | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | —                                            | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | —                                                                | —                              |
| L1 NFT vaults     | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | —                                            | —                                            | —                                                                | —                              |
| L1 BridgedERC721  | —                                            | —                                            | —                                            | —                                                                | `erc721Vault()` `0x0b470dd3…`  |
| L1 BridgedERC1155 | —                                            | —                                            | —                                            | —                                                                | `erc1155Vault()` `0xaf145913…` |
| L2 bridge         | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | `0x1670000000000000000000000000000000000005` | zero                                         | zero                                                             | `recallEnabled()` `false`      |
| L2 ERC20 vault    | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | —                                            | zero                                         | —                                                                | —                              |
| L2 NFT vaults     | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | —                                            | —                                            | —                                                                | —                              |
| L2 BridgedERC721  | —                                            | —                                            | —                                            | —                                                                | `erc721Vault()` `0x1670…0003`  |
| L2 BridgedERC1155 | —                                            | —                                            | —                                            | —                                                                | `erc1155Vault()` `0x1670…0004` |

The L2 zeros preserve today's behaviour: L2 has no quota and only the owner can pause. The recall
switch is off on L2 too, so an L1 → L2 message can no longer be marked `FAILED` there, which is
what an L1 recall proves, and an L2 → L1 message can no longer be recalled.

The L1 resolver already names every counterpart the new NFT vaults read (verified 2026-09-23):
`bridge`, `erc721_vault` and `erc1155_vault` for both chains. Its `bridged_erc721` and
`bridged_erc1155` entries for chain 1 name the May 2024 implementations `0xC3310905…` and
`0x3c90963c…`, whose bytecode has only the six-argument `init` (`0xef8c4ae6`), not the
five-argument one the new vaults call (`0xd1399b1a`); the L2 legacy implementations
`0x0167…010097` and `0x0167…010098` are the same. That is why actions L1 3–4 and L2 5–6 exist.

Preconditions to re-read at execution time, as for Proposal0024: neither bridge may be paused (the
appended L1 `sendMessage` and the L2 `processMessage` that delivers the batch are both
`whenNotPaused`), and Proposal0024 must have executed on both chains, which is what
[Verification](#verification) checks first.

## What Changes

### Bridges and ERC20 vaults: #22156

The diff of #22156 against the code Proposal0024 installs:

- `Bridge` gains the constructor argument and immutable `recallEnabled`, `false` in both bridge
  implementations here. While it is false, `failMessage` and `recallMessage` revert with
  `B_RECALL_DISABLED` before anything else runs, and `retryMessage` no longer marks a failed last
  attempt `FAILED`: it reverts with `B_RETRY_FAILED` like any other failed retry.
- The recall code itself stays, without its quota debit: `Bridge.recallMessage` no longer calls
  `_consumeEtherQuota`, and `ERC20Vault.onMessageInvocation` debits the token quota right after
  `_transferTokens` instead of inside it, so a delivery is still debited atomically with its
  release while a refund (`onMessageRecalled`) is not. Neither is reachable while recalls are off.

What a user or relayer can observe:

- No message can enter `FAILED` or `RECALLED` on either chain. A message whose delivery fails
  stays `RETRIABLE` until a retry succeeds; a succeeding last attempt still marks it `DONE`.
- A message already `FAILED` on its destination chain when this executes is stranded: it can be
  neither retried (`B_INVALID_STATUS`) nor recalled (`B_RECALL_DISABLED`). The census in #22156
  (2026-09-22) found 2 such messages, neither carrying Ether, and 10 `RETRIABLE` ones (6 on L1,
  4 on L2) that keep their retry path but lose the fail-then-recall escape. Whether to retry, or
  fail and recall, any of them is worth deciding before this proposal executes.
- The bridge-ui Release dialog (`recallMessage`) and its "retry one final time" option
  (`retryMessage(_, true)`) now revert with an error its checked-in ABI cannot decode (#22159).
- Deliveries, retries, sends, fees, events, the `Message` struct and `hashMessage` are unchanged,
  as is who can pause. The quota configuration on the `QuotaManager` is unchanged.

### NFT vaults: protocol 1.10.0 to `main`

The NFT vaults skip from `9345f14` to `main`, the same jump Proposal0024 makes for the L2 ERC20
vault. Against the live implementations:

- Every name resolves through the shared resolver (`IResolver.resolve`) instead of the
  AddressManager (`getAddress`). `addressManager()` and `lastUnpausedAt()` disappear from the ABI,
  `resolver()` appears. The reentrancy lock moves to transient storage.
- A bridged token deployed from now on is initialised through the five-argument `init` (no
  AddressManager) and mints and burns only for its `erc721Vault` / `erc1155Vault` immutable, the
  vault proxy. Its owner is still the vault's owner.
- Bridged tokens the old vaults deployed keep working unchanged: they authorise the vault through
  the AddressManager, which keeps naming the same proxy, and they implement exactly the
  `mint(address,uint256)` / `burn(uint256)` and `mintBatch(address,uint256[],uint256[])` /
  `burn(uint256,uint256)` the new vaults call (checked on the bytecode of all four legacy
  implementations). The vault still takes the token into custody before burning it, as the legacy
  `burn` requires.
- `sendToken` now also rejects a recipient equal to the destination chain's vault
  (`checkToAddressOnSrcChain`), and `onMessageRecalled` is guarded by `onlyFromNamed(bridge)`
  instead of `checkRecallMessageContext`; the second is unreachable while recalls are off.
- The message format (`CanonicalNFT` and the `onMessageInvocation` payload), the events, the
  errors and the `IBridge.Context` the vaults read are unchanged, so an NFT message sent by the old
  vault on one chain is delivered by the new vault on the other, and vice versa, in the window
  between the L1 leg executing and the L2 batch being delivered.

## Upgrade Safety

### Storage layout

`Bridge_Layout.sol` and `ERC20Vault_Layout.sol` are untouched by #22156, and
`script/gen-layouts.sh shared` regenerates them without a diff: neither contract adds, removes or
moves a storage variable (`recallEnabled` is an immutable). The layouts are the ones Proposal0024
verified slot by slot against the live proxies.

For the NFT vaults, the layout generated at `9345f14` (`contract_layout_layer1.md` and
`contract_layout_layer2.md` in that commit, identical on both chains) matches `ERC721Vault_Layout.sol`
and `ERC1155Vault_Layout.sol` slot for slot. The only named variables are at slots 0, 51, 101, 151,
201, 301 and 302; slot 151 (`addressManager`) becomes part of `__gapFromOldAddressResolver`, and
`lastUnpausedAt` (slot 201, bytes 2–9) is no longer read, while `__paused` stays at slot 201,
byte 1. `bridgedToCanonical` and `canonicalToBridged` stay at slots 301 and 302, which the fork
rehearsal confirms by minting and burning, through the new implementations, a collection the old
ones bridged in. No initializer runs in this proposal and none is needed.

### The L2 bridge upgrades itself mid-call

As in Proposal0024, the L2 bridge proxy is owned by the DelegateController, reachable only through
a bridged message the L2 bridge itself processes, so `upgradeTo` on it executes inside the bridge's
own `processMessage` frame. The analysis Proposal0024 made holds, and is simpler here because both
the outgoing and the incoming implementation are `main`-era code:

1. `_authorizeUpgrade` is `onlyOwner` with no `nonReentrant`.
2. `DelegateController.onMessageInvocation` reads `IBridge(msg.sender).context()` before
   `_executeActions`, from the transient `_CTX_SLOT` the outgoing implementation populated.
3. Both implementations keep the call context in `_CTX_SLOT` (`0xe4ece821…dbadc2b9`) and the
   reentrancy lock in `_REENTRY_SLOT` (`0xa5054f72…31d9721b`): #22156 touches neither constant.
4. The old frame's remaining writes after the swap, the context reset, `messageStatus`, the
   `MessageProcessed` event and the `nonReentrant` epilogue, land on slots the new implementation
   agrees with, and the frame makes no call back into the proxy. The message carries `value: 0`
   and `fee: 0`, so there is no refund path.

The resolver entries and the three vault upgrades are plain owner calls, ordered before the bridge
swap so the batch makes no further call once the bridge's code has changed under its frame.
`test/layer1/proposals/Proposal0025Fork.t.sol` rehearses both legs against live state; see
[Verification](#verification).

### EVM version and ABI

`evm_version = "osaka"` and transient storage already live on both chains, as in Proposal0024. The
`ERC20Vault` ABI is unchanged; the `Bridge` ABI gains the `recallEnabled()` getter, the
`B_RECALL_DISABLED` error and the fifth constructor argument. The NFT vault ABI changes are listed
under [What Changes](#nft-vaults-protocol-1100-to-main).

## Action Order

### L1 — 7 top-level actions

1. `upgradeTo(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, [new-impl-placeholder])` — the mainnet
   bridge.
2. `upgradeTo(0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, [new-impl-placeholder])` — the mainnet
   ERC20 vault.
3. `registerAddress(1, "bridged_erc721", [new-impl-placeholder])` on the L1 shared resolver
   `0x8Efa01564425692d0a0838DC10E300BD310Cb43e`.
4. `registerAddress(1, "bridged_erc1155", [new-impl-placeholder])` on the same resolver.
5. `upgradeTo(0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa, [new-impl-placeholder])` — the mainnet
   ERC721 vault.
6. `upgradeTo(0xaf145913EA4a56BE22E120ED9C24589659881702, [new-impl-placeholder])` — the mainnet
   ERC1155 vault.
7. `sendMessage(...)` on `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` — carries the L2 batch to
   the DelegateController. Not written in `Proposal0025.s.sol`: `BuildProposal._buildAllActions()`
   appends it whenever `buildL2Actions()` is non-empty, with `value: 0`, zero fee,
   `gasLimit = 5_000_000`, `srcOwner` = the DAO controller, `to` = the DelegateController
   `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` and `destOwner` = `PERMISSIONLESS_EXECUTOR`
   `0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA`, so anyone can relay it.

The message is sent through the just-upgraded bridge, so the new implementation's `sendMessage`
runs in the same transaction it goes live. The L1 dry run and the fork rehearsal both prove that.

### L2 — 10 actions, `l2ExecutionId = 0`, `l2GasLimit = 5_000_000`

Numbered from 1 here, `actions[0]` to `actions[9]` in `Proposal0025.s.sol`. Actions 1–6 are
`registerAddress` calls on the L2 shared resolver `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984`.

1. `erc721_vault` for chain 1 → `0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa`, read on every delivery,
   send and recipient check.
2. `erc1155_vault` for chain 1 → `0xaf145913EA4a56BE22E120ED9C24589659881702`, likewise.
3. `erc721_vault` for chain 167000 → `0x1670000000000000000000000000000000000003`, read by nothing
   today; registered for symmetry with the L1 resolver, as Proposal0024 did for `erc20_vault`.
4. `erc1155_vault` for chain 167000 → `0x1670000000000000000000000000000000000004`, likewise.
5. `bridged_erc721` for chain 167000 → `[new-impl-placeholder]`, read on the first delivery of a
   collection the vault has not seen.
6. `bridged_erc1155` for chain 167000 → `[new-impl-placeholder]`, likewise.
7. `upgradeTo(0x1670000000000000000000000000000000000003, [new-impl-placeholder])` — the ERC721
   vault.
8. `upgradeTo(0x1670000000000000000000000000000000000004, [new-impl-placeholder])` — the ERC1155
   vault.
9. `upgradeTo(0x1670000000000000000000000000000000000002, [new-impl-placeholder])` — the ERC20
   vault.
10. `upgradeTo(0x1670000000000000000000000000000000000001, [new-impl-placeholder])` — the bridge's
    mid-call self-upgrade, deliberately last.

The `bridge` entry for chain 167000 that the new NFT vaults also read (their `onlyFromNamed` guard
and every send) is registered by Proposal0024.

Parameter choices: `l2ExecutionId = 0` is the unordered mode Proposal0024 used.
`l2GasLimit = 5_000_000` matches Proposal0024; after the bridge deducts `GAS_RESERVE` (800,000)
and the calldata charge (51,712 for this 2,788-byte message), a relayer-driven invocation gets
4,148,288 gas, about sixteen times the ~254,000 the ten actions use in the fork rehearsal.
`Proposal0025.t.sol` pins the 2,788 and the fork test's relayer case pins the 4,148,288; re-derive
both together if the action list changes.

## Deployment

**TODO(@davidtaikocha): deploy the twelve contracts and wire their addresses in.** Until then
every builder in `Proposal0025.s.sol` reverts `ImplementationNotDeployed`, the action file cannot
be generated and `test_actionFileMatchesTheBuiltCalldata` is skipped.

Deploy from this branch, or from `main` once this PR is merged (#22156 already is). Both scripts
deploy contracts only, no proxy upgrade, no registration and no initializer call, and read the live
chain before broadcasting: `DeployProposal0025L1` aborts unless the live L1 bridge and ERC20 vault
answer the resolver, signal service, quota manager and pauser it is about to bake in, and the L1
resolver names the two NFT vault proxies the bridged tokens bind to; `DeployProposal0025L2` unless
the L2 resolver is owned by the DelegateController and the L2 NFT vault proxies answer their names.
After broadcasting, both abort unless every new contract carries the intended immutables,
`recallEnabled() == false` included. Neither should be re-run: a second run deploys contracts the
constants do not point at. Each script sends six transactions (about 26M gas in total).

1. Deploy on Ethereum. The script logs `BRIDGE_NEW_IMPL_L1`, `ERC20_VAULT_NEW_IMPL_L1`,
   `ERC721_VAULT_NEW_IMPL_L1`, `ERC1155_VAULT_NEW_IMPL_L1`, `LibL1Addrs.BRIDGED_ERC721` and
   `LibL1Addrs.BRIDGED_ERC1155`.

   ```bash
   cd packages/protocol
   export ETHERSCAN_API_KEY=<key>
   PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
     script/layer1/mainnet/DeployProposal0025L1.s.sol:DeployProposal0025L1 \
     --rpc-url <L1_RPC> --broadcast --verify
   ```

2. Deploy on Taiko. The script logs the same six names with `L2`.

   ```bash
   PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
     script/layer2/mainnet/DeployProposal0025L2.s.sol:DeployProposal0025L2 \
     --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --verify
   ```

   Check that every logged address has code (`cast codesize`): forge can report success for a
   broadcast whose transactions the RPC dropped.

3. Write the addresses in:

   - the eight implementations into the constants of `Proposal0025.s.sol` and the `newimpl=` of
     the codediff link above each;
   - the four bridged-token implementations into `LibL1Addrs.BRIDGED_ERC721`,
     `LibL1Addrs.BRIDGED_ERC1155`, `LibL2Addrs.BRIDGED_ERC721` and `LibL2Addrs.BRIDGED_ERC1155`,
     replacing the legacy values with a comment naming them, and into the matching entries of the
     unused hardcoded `MainnetSharedResolver` and `SharedResolver`, as Proposal0024 did for
     `bridged_erc20`;
   - all twelve into the `DEPLOYED_*` literals of `test/layer1/proposals/Proposal0025.t.sol`;
   - all twelve into the tables of this runbook, replacing every `[new-impl-placeholder]`.

4. Regenerate the calldata and check it in: `P=0025 pnpm proposal` writes
   `Proposal0025.action.md`. `test_actionFileMatchesTheBuiltCalldata` compares it against the
   builders from then on, and a second reviewer should re-run the command and diff the file.

5. Simulate both legs against the live chains and run the fork rehearsal (commands under
   [Verification](#verification)). Both dry runs revert with `DryrunSucceeded()`, which is the
   success signal; `Controller.dryrun` always reverts, so the `--broadcast` in the
   `pnpm proposal:dryrun:*` scripts can never send anything.

6. Authenticate the code with `forge verify-bytecode` (commands under
   [Verification](#verification)) and update `deployments/mainnet-contract-logs-L1.md` and
   `deployments/mainnet-contract-logs-L2.md` with the creation transactions.

## Deployed Addresses

| What                               | Address                  |                                 |
| ---------------------------------- | ------------------------ | ------------------------------- |
| L1 `Bridge` implementation         | `[new-impl-placeholder]` | proxy upgrade                   |
| L1 `ERC20Vault` implementation     | `[new-impl-placeholder]` | proxy upgrade                   |
| L1 `ERC721Vault` implementation    | `[new-impl-placeholder]` | proxy upgrade                   |
| L1 `ERC1155Vault` implementation   | `[new-impl-placeholder]` | proxy upgrade                   |
| L1 `BridgedERC721` implementation  | `[new-impl-placeholder]` | registered as `bridged_erc721`  |
| L1 `BridgedERC1155` implementation | `[new-impl-placeholder]` | registered as `bridged_erc1155` |
| L2 `Bridge` implementation         | `[new-impl-placeholder]` | proxy upgrade                   |
| L2 `ERC20Vault` implementation     | `[new-impl-placeholder]` | proxy upgrade                   |
| L2 `ERC721Vault` implementation    | `[new-impl-placeholder]` | proxy upgrade                   |
| L2 `ERC1155Vault` implementation   | `[new-impl-placeholder]` | proxy upgrade                   |
| L2 `BridgedERC721` implementation  | `[new-impl-placeholder]` | registered as `bridged_erc721`  |
| L2 `BridgedERC1155` implementation | `[new-impl-placeholder]` | registered as `bridged_erc1155` |

Codediff of each change, `addr` being what it replaces. The bridges and ERC20 vaults keep running
the pre-Proposal0024 code until that proposal executes, so their `addr` is the implementation
Proposal0024 installs rather than the proxy, and each diff shows exactly the delta this proposal
ships:

| Contract          | codediff                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| L1 Bridge         | https://codediff.taiko.xyz/?addr=0xA15dca0A72da684f20e0FC708DECFb230a715462&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 ERC20Vault     | https://codediff.taiko.xyz/?addr=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 ERC721Vault    | https://codediff.taiko.xyz/?addr=0xA4C5c20aB33C96B1c281Dca37D03E23609274C49&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 ERC1155Vault   | https://codediff.taiko.xyz/?addr=0x838ed469db456b67EB3b0B74D759Be4DA999b9c8&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 BridgedERC721  | https://codediff.taiko.xyz/?addr=0xC3310905E2BC9Cfb198695B75EF3e5B69C6A1Bf7&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 BridgedERC1155 | https://codediff.taiko.xyz/?addr=0x3c90963cFBa436400B0F9C46Aa9224cB379c2c40&newimpl=[new-impl-placeholder]&chainid=1      |
| L2 Bridge         | https://codediff.taiko.xyz/?addr=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 ERC20Vault     | https://codediff.taiko.xyz/?addr=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 ERC721Vault    | https://codediff.taiko.xyz/?addr=0xd532f20a4751156C566Da7745db95E7f80145B36&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 ERC1155Vault   | https://codediff.taiko.xyz/?addr=0xBBBC4ad39488b990E095042fa6c59A90d3817846&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 BridgedERC721  | https://codediff.taiko.xyz/?addr=0x0167000000000000000000000000000000010097&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 BridgedERC1155 | https://codediff.taiko.xyz/?addr=0x0167000000000000000000000000000000010098&newimpl=[new-impl-placeholder]&chainid=167000 |

Each bridge diff should show only #22156: the `recallEnabled` switch and its guards, the removed
debit in `recallMessage`, and the documentation around them. Each ERC20 vault diff should show
#22156's moved debit and its documentation, plus the one-line comment #22131 removed after the
Proposal0024 vaults were built. The NFT vault and bridged-token diffs span protocol 1.10.0 to
`main`: the move to the resolver and the changes listed under
[What Changes](#nft-vaults-protocol-1100-to-main).

## Verification

Every commented value is the expected result. Run after the addresses are wired in.

```bash
export L1_RPC=<l1 rpc>
export L2_RPC=https://rpc.mainnet.taiko.xyz
export IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

# Proposal0024 has executed: the proxies run the implementations this proposal replaces.
cast storage 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC $IMPL_SLOT --rpc-url $L1_RPC  # 0x…A15dca0A72da684f20e0FC708DECFb230a715462
cast storage 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab $IMPL_SLOT --rpc-url $L1_RPC  # 0x…32E47c04E8c329E8c10062731448e7658aDEEB8e
cast storage 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa $IMPL_SLOT --rpc-url $L1_RPC  # 0x…A4C5c20aB33C96B1c281Dca37D03E23609274C49
cast storage 0xaf145913EA4a56BE22E120ED9C24589659881702 $IMPL_SLOT --rpc-url $L1_RPC  # 0x…838ed469db456b67EB3b0B74D759Be4DA999b9c8
cast storage 0x1670000000000000000000000000000000000001 $IMPL_SLOT --rpc-url $L2_RPC  # 0x…a200c2268d77737a8Fd2CA1698dA6eeab2a85CEb
cast storage 0x1670000000000000000000000000000000000002 $IMPL_SLOT --rpc-url $L2_RPC  # 0x…a01d464ca3982DAa97B19fa7F8a232eB11A9DDb3
cast storage 0x1670000000000000000000000000000000000003 $IMPL_SLOT --rpc-url $L2_RPC  # 0x…d532f20a4751156C566Da7745db95E7f80145B36
cast storage 0x1670000000000000000000000000000000000004 $IMPL_SLOT --rpc-url $L2_RPC  # 0x…BBBC4ad39488b990E095042fa6c59A90d3817846

# New implementations' immutables; the L1 bridge and ERC20 vault ones must equal the live proxies'.
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e   (bridge)
cast call [new-impl-placeholder] "signalService()(address)" --rpc-url $L1_RPC  # 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call [new-impl-placeholder] "pauser()(address)"        --rpc-url $L1_RPC  # 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F
cast call [new-impl-placeholder] "recallEnabled()(bool)"    --rpc-url $L1_RPC  # false
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e   (ERC20 vault)
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC   (ERC20 vault)
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e   (ERC721 vault)
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e   (ERC1155 vault)
cast call [new-impl-placeholder] "erc721Vault()(address)"   --rpc-url $L1_RPC  # 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa
cast call [new-impl-placeholder] "erc1155Vault()(address)"  --rpc-url $L1_RPC  # 0xaf145913EA4a56BE22E120ED9C24589659881702
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984   (bridge)
cast call [new-impl-placeholder] "signalService()(address)" --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000005
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call [new-impl-placeholder] "pauser()(address)"        --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call [new-impl-placeholder] "recallEnabled()(bool)"    --rpc-url $L2_RPC  # false
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984   (ERC20 vault)
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000   (ERC20 vault)
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984   (ERC721 vault)
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984   (ERC1155 vault)
cast call [new-impl-placeholder] "erc721Vault()(address)"   --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000003
cast call [new-impl-placeholder] "erc1155Vault()(address)"  --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000004

# The quota configuration is not touched by the proposal; record it before and after.
cast call 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC "availableQuota(address,uint256)(uint256)" 0x0000000000000000000000000000000000000000 0 --rpc-url $L1_RPC  # 250 ETH when full
cast call 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC "quotaPeriod()(uint24)" --rpc-url $L1_RPC  # 86400

# Authenticate the code, not just the getters. Pass signal: "Creation code matched with status full".
export ETHERSCAN_API_KEY=<key>
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address,bool)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C \
    0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F false)
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x8Efa01564425692d0a0838DC10E300BD310Cb43e 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC)
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC721Vault.sol:ERC721Vault --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x8Efa01564425692d0a0838DC10E300BD310Cb43e)
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC1155Vault.sol:ERC1155Vault --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x8Efa01564425692d0a0838DC10E300BD310Cb43e)
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/BridgedERC721.sol:BridgedERC721 --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa)
FOUNDRY_PROFILE=layer1 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/BridgedERC1155.sol:BridgedERC1155 --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0xaf145913EA4a56BE22E120ED9C24589659881702)
# First argument of the L2 bridge and vaults is the resolver PROXY, not its implementation.
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address,bool)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x1670000000000000000000000000000000000005 \
    0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 false)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x0000000000000000000000000000000000000000)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC721Vault.sol:ERC721Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC1155Vault.sol:ERC1155Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/BridgedERC721.sol:BridgedERC721 --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x1670000000000000000000000000000000000003)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/BridgedERC1155.sol:BridgedERC1155 --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address)" 0x1670000000000000000000000000000000000004)

# Simulate both legs against the live chains; both revert with DryrunSucceeded().
cd packages/protocol
MODE=l1dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0025.s.sol:Proposal0025 --rpc-url $L1_RPC
MODE=l2dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0025.s.sol:Proposal0025 --rpc-url $L2_RPC

# Rehearse the exact batch against live state; all five tests must pass. While the fork still
# predates Proposal0024 the rehearsal executes that batch first; while the constants are
# placeholders it builds the contracts from the tree. On L1 it pins the defect on the Proposal0024
# code (a recall drains the Ether quota, a refund debits the WETH quota), executes the batch, and
# shows the same recalls reverting with B_RECALL_DISABLED afterwards, both quotas untouched, while a
# real withdrawal is still debited. On L2 it delivers the batch through processMessage, then sends,
# delivers bridged USDT and serves a second governance message through the upgraded bridge. On
# both chains the NFT rehearsal bridges a collection in through the old NFT vaults, executes the
# batch, and then, through the new vaults, mints more of that collection and bridges it back out,
# deploys a never-seen collection behind the new bridged-token implementation, and custodies and
# releases a collection native to the chain, for ERC721 and ERC1155 alike.
L1_FORK_URL=$L1_RPC L2_FORK_URL=$L2_RPC FOUNDRY_PROFILE=layer1 \
  forge test --match-contract Proposal0025ForkTest -vv
```

The L2 dry run calls `DelegateController.dryrun` directly and so does not exercise the mid-call
self-upgrade; only the fork test does.

## After Execution

- Record the upgrades and registrations in `deployments/mainnet-contract-logs-L1.md` and
  `deployments/mainnet-contract-logs-L2.md`, including that the NFT vaults no longer read the
  legacy AddressManagers.
- Re-read the eight implementation slots (first block of [Verification](#verification)) against
  the new addresses, confirm `recallEnabled()` reads `false` through both bridge proxies and
  `resolver()` reads the shared resolver through all four NFT vault proxies, and resolve the new
  entries:

  ```bash
  cast call 0x8Efa01564425692d0a0838DC10E300BD310Cb43e "resolve(uint256,bytes32,bool)(address)" 1 $(cast format-bytes32-string bridged_erc721) false --rpc-url $L1_RPC       # the new L1 BridgedERC721
  cast call 0x8Efa01564425692d0a0838DC10E300BD310Cb43e "resolve(uint256,bytes32,bool)(address)" 1 $(cast format-bytes32-string bridged_erc1155) false --rpc-url $L1_RPC      # the new L1 BridgedERC1155
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 1 $(cast format-bytes32-string erc721_vault) false --rpc-url $L2_RPC         # 0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 1 $(cast format-bytes32-string erc1155_vault) false --rpc-url $L2_RPC        # 0xaf145913EA4a56BE22E120ED9C24589659881702
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 167000 $(cast format-bytes32-string erc721_vault) false --rpc-url $L2_RPC    # 0x1670000000000000000000000000000000000003
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 167000 $(cast format-bytes32-string erc1155_vault) false --rpc-url $L2_RPC   # 0x1670000000000000000000000000000000000004
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 167000 $(cast format-bytes32-string bridged_erc721) false --rpc-url $L2_RPC  # the new L2 BridgedERC721
  cast call 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 "resolve(uint256,bytes32,bool)(address)" 167000 $(cast format-bytes32-string bridged_erc1155) false --rpc-url $L2_RPC # the new L2 BridgedERC1155
  ```
