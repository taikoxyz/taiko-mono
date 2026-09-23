# PROPOSAL-0025: Disable Message Recalls and Failure Marking on the L1 and L2 Bridges

## Executive Summary

Proposal0025 ships [PR #22156](https://github.com/taikoxyz/taiko-mono/pull/22156) to production by
upgrading the same four proxies Proposal0024 upgrades, two per chain, to implementations built from
`main` after that PR. No other contract source change ships with it: deploy scripts, the DAO
proposal, this runbook and tests only.

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

**This proposal executes after Proposal0024.** The implementations it replaces are the ones
Proposal0024 installs (`0xA15dca0A…`, `0x32E47c04…`, `0xa200c226…`, `0xa01d464c…`), all of which
were built before #22156 and carry the defect, and the L2 implementations read the resolver
Proposal0024 populates. Were Proposal0024 to execute after this one it would reinstall the
defective code, so the DAO must sequence them: Proposal0024 first, then Proposal0025.

The proposal executes **3 top-level L1 actions** and **2 L2 actions**. The four implementations
are **not deployed yet**; see [Deployment](#deployment).

## Scope

| Chain | Contract                                                      | Change                                    |
| ----- | ------------------------------------------------------------- | ----------------------------------------- |
| L1    | Bridge proxy `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC`     | implementation → `[new-impl-placeholder]` |
| L1    | ERC20Vault proxy `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | implementation → `[new-impl-placeholder]` |
| L2    | Bridge proxy `0x1670000000000000000000000000000000000001`     | implementation → `[new-impl-placeholder]` |
| L2    | ERC20Vault proxy `0x1670000000000000000000000000000000000002` | implementation → `[new-impl-placeholder]` |

Not touched: the `QuotaManager` `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` and its per-token
quotas; both resolvers and every entry on them; ownership (no `transferOwnership`,
`acceptOwnership` or initializer call on any live contract); the NFT vaults; Hoodi and every other
network.

## Prerequisite: Proposal0024

Verified on-chain on 2026-09-22 (L1 block 26,031,706, L2 block 11,717,269): Proposal0024 has not
executed. The L1 bridge and vault still run the Proposal0017 implementations
(`0x1c94D798…`, `0x024253C6…`), the L2 bridge and vault still run protocol 1.10.0
(`0x95ae2918…`, `0xb96AbB41…`), and the new L2 resolver `0x2ea05A9C…` is deployed but empty.

Proposal0025 assumes the state Proposal0024 leaves behind, and nothing else:

|           | proxy                                        | owner                                                                                | implementation after Proposal0024            |
| --------- | -------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- |
| L1 bridge | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0xA15dca0A72da684f20e0FC708DECFb230a715462` |
| L1 vault  | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | DAO controller                                                                       | `0x32E47c04E8c329E8c10062731448e7658aDEEB8e` |
| L2 bridge | `0x1670000000000000000000000000000000000001` | DelegateController `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C`                      | `0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb` |
| L2 vault  | `0x1670000000000000000000000000000000000002` | DelegateController                                                                   | `0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3` |

The new implementations carry exactly the immutables of those four, which both deploy scripts
check before and after broadcasting, plus the bridges' new `recallEnabled`, `false` on both chains,
which they check after broadcasting:

| Contract  | `resolver()`                                 | `signalService()`                            | `quotaManager()`                             | `pauser()`                                                       | `recallEnabled()` |
| --------- | -------------------------------------------- | -------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------- | ----------------- |
| L1 bridge | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | `0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F` (`admin.taiko.eth`) | `false`           |
| L1 vault  | `0x8Efa01564425692d0a0838DC10E300BD310Cb43e` | —                                            | `0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC` | —                                                                | —                 |
| L2 bridge | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | `0x1670000000000000000000000000000000000005` | zero                                         | zero                                                             | `false`           |
| L2 vault  | `0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984` | —                                            | zero                                         | —                                                                | —                 |

The L2 zeros preserve today's behaviour: L2 has no quota and only the owner can pause. The recall
switch is off on L2 too, so an L1 → L2 message can no longer be marked `FAILED` there, which is
what an L1 recall proves, and an L2 → L1 message can no longer be recalled.

Preconditions to re-read at execution time, as for Proposal0024: neither bridge may be paused (the
appended L1 `sendMessage` and the L2 `processMessage` that delivers the batch are both
`whenNotPaused`), and Proposal0024 must have executed on both chains, which is what
[Verification](#verification) checks first.

## What Changes

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

## Upgrade Safety

### Storage layout

`Bridge_Layout.sol` and `ERC20Vault_Layout.sol` are untouched by #22156, and
`script/gen-layouts.sh shared` regenerates them without a diff: neither contract adds, removes or
moves a storage variable (`recallEnabled` is an immutable). The layouts are the ones Proposal0024
verified slot by slot against the live proxies, so nothing about that analysis changes. No
initializer runs in this proposal and none is needed.

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

The vault upgrade is a plain owner upgrade, ordered before the bridge swap so the batch makes no
further call once the bridge's code has changed under its frame.
`test/layer1/proposals/Proposal0025Fork.t.sol` rehearses both legs against live state; see
[Verification](#verification).

### EVM version and ABI

`evm_version = "osaka"` and transient storage already live on both chains, as in Proposal0024. The
`ERC20Vault` ABI is unchanged; the `Bridge` ABI gains the `recallEnabled()` getter, the
`B_RECALL_DISABLED` error and the fifth constructor argument.

## Action Order

### L1 — 3 top-level actions

1. `upgradeTo(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC, [new-impl-placeholder])` — the mainnet
   bridge.
2. `upgradeTo(0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab, [new-impl-placeholder])` — the mainnet
   ERC20 vault.
3. `sendMessage(...)` on `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` — carries the L2 batch to
   the DelegateController. Not written in `Proposal0025.s.sol`: `BuildProposal._buildAllActions()`
   appends it whenever `buildL2Actions()` is non-empty, with `value: 0`, zero fee,
   `gasLimit = 5_000_000`, `srcOwner` = the DAO controller, `to` = the DelegateController
   `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` and `destOwner` = `PERMISSIONLESS_EXECUTOR`
   `0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA`, so anyone can relay it.

The message is sent through the just-upgraded bridge, so the new implementation's `sendMessage`
runs in the same transaction it goes live. The L1 dry run and the fork rehearsal both prove that.

### L2 — 2 actions, `l2ExecutionId = 0`, `l2GasLimit = 5_000_000`

Numbered from 1 here, `actions[0]` and `actions[1]` in `Proposal0025.s.sol`.

1. `upgradeTo(0x1670000000000000000000000000000000000002, [new-impl-placeholder])` — the vault.
2. `upgradeTo(0x1670000000000000000000000000000000000001, [new-impl-placeholder])` — the bridge's
   mid-call self-upgrade, deliberately last.

Parameter choices: `l2ExecutionId = 0` is the unordered mode Proposal0024 used.
`l2GasLimit = 5_000_000` matches Proposal0024; after the bridge deducts `GAS_RESERVE` (800,000)
and the calldata charge (16,896 for this 612-byte message), a relayer-driven invocation gets
4,183,104 gas, more than twenty times what two upgrades need. `Proposal0025.t.sol` pins the 612
and the fork test's relayer case pins the 4,183,104; re-derive both together if the action list
changes.

## Deployment

**TODO(@davidtaikocha): deploy the four implementations and wire their addresses in.** Until then
every builder in `Proposal0025.s.sol` reverts `ImplementationNotDeployed`, the action file cannot
be generated and `test_actionFileMatchesTheBuiltCalldata` is skipped.

Deploy from this branch, or from `main` once this PR is merged (#22156 already is). Both scripts
deploy implementations only, no proxy upgrade and no initializer call, and read the live chain
before broadcasting: `DeployProposal0025L1` aborts unless the live L1 proxies answer the resolver,
signal service, quota manager and pauser it is about to bake in, `DeployProposal0025L2` unless the
L2 resolver is owned by the DelegateController. After broadcasting, both abort unless the new
implementations carry the intended immutables, `recallEnabled() == false` included. Neither should
be re-run: a second run deploys contracts the constants do not point at.

1. Deploy on Ethereum. The script logs `BRIDGE_NEW_IMPL_L1` and `ERC20_VAULT_NEW_IMPL_L1`.

   ```bash
   cd packages/protocol
   PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer1 forge script \
     script/layer1/mainnet/DeployProposal0025L1.s.sol:DeployProposal0025L1 \
     --rpc-url <L1_RPC> --broadcast --verify
   ```

2. Deploy on Taiko. The script logs `BRIDGE_NEW_IMPL_L2` and `ERC20_VAULT_NEW_IMPL_L2`.

   ```bash
   PRIVATE_KEY=<deployer> FOUNDRY_PROFILE=layer2 forge script \
     script/layer2/mainnet/DeployProposal0025L2.s.sol:DeployProposal0025L2 \
     --rpc-url https://rpc.mainnet.taiko.xyz --broadcast --verify
   ```

3. Write the four logged addresses into `Proposal0025.s.sol` (the four constants and the
   `newimpl=` of the codediff link above each), into the `DEPLOYED_*` literals of
   `test/layer1/proposals/Proposal0025.t.sol`, and into the tables of this runbook, replacing every
   `[new-impl-placeholder]`.

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

| What                           | Address                  |               |
| ------------------------------ | ------------------------ | ------------- |
| L1 `Bridge` implementation     | `[new-impl-placeholder]` | proxy upgrade |
| L1 `ERC20Vault` implementation | `[new-impl-placeholder]` | proxy upgrade |
| L2 `Bridge` implementation     | `[new-impl-placeholder]` | proxy upgrade |
| L2 `ERC20Vault` implementation | `[new-impl-placeholder]` | proxy upgrade |

Codediff of each upgrade. Because the proxies keep running the pre-Proposal0024 code until that
proposal executes, `addr` is the implementation Proposal0024 installs rather than the proxy, so
each diff shows exactly the delta this proposal ships:

| Contract      | codediff                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------------------------- |
| L1 Bridge     | https://codediff.taiko.xyz/?addr=0xA15dca0A72da684f20e0FC708DECFb230a715462&newimpl=[new-impl-placeholder]&chainid=1      |
| L1 ERC20Vault | https://codediff.taiko.xyz/?addr=0x32E47c04E8c329E8c10062731448e7658aDEEB8e&newimpl=[new-impl-placeholder]&chainid=1      |
| L2 Bridge     | https://codediff.taiko.xyz/?addr=0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb&newimpl=[new-impl-placeholder]&chainid=167000 |
| L2 ERC20Vault | https://codediff.taiko.xyz/?addr=0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3&newimpl=[new-impl-placeholder]&chainid=167000 |

Each bridge diff should show only #22156: the `recallEnabled` switch and its guards, the removed
debit in `recallMessage`, and the documentation around them. Each vault diff should show #22156's
moved debit and its documentation, plus the one-line comment #22131 removed after the
Proposal0024 vaults were built.

## Verification

Every commented value is the expected result. Run after the addresses are wired in.

```bash
export L1_RPC=<l1 rpc>
export L2_RPC=https://rpc.mainnet.taiko.xyz

# Proposal0024 has executed: the proxies run the implementations this proposal replaces.
cast storage 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC  # 0x…A15dca0A72da684f20e0FC708DECFb230a715462
cast storage 0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC  # 0x…32E47c04E8c329E8c10062731448e7658aDEEB8e
cast storage 0x1670000000000000000000000000000000000001 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L2_RPC  # 0x…a200c2268d77737a8Fd2CA1698dA6eeab2a85CEb
cast storage 0x1670000000000000000000000000000000000002 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L2_RPC  # 0x…a01d464ca3982DAa97B19fa7F8a232eB11A9DDb3

# New implementations' immutables; the L1 ones must equal the live proxies'.
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e
cast call [new-impl-placeholder] "signalService()(address)" --rpc-url $L1_RPC  # 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC
cast call [new-impl-placeholder] "pauser()(address)"        --rpc-url $L1_RPC  # 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F
cast call [new-impl-placeholder] "recallEnabled()(bool)"    --rpc-url $L1_RPC  # false
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L1_RPC  # 0x8Efa01564425692d0a0838DC10E300BD310Cb43e   (vault)
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L1_RPC  # 0xBaCb003f0B13CeAF09Eb9Baf5915A640BD4Bc6cC   (vault)
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984
cast call [new-impl-placeholder] "signalService()(address)" --rpc-url $L2_RPC  # 0x1670000000000000000000000000000000000005
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call [new-impl-placeholder] "pauser()(address)"        --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000
cast call [new-impl-placeholder] "recallEnabled()(bool)"    --rpc-url $L2_RPC  # false
cast call [new-impl-placeholder] "resolver()(address)"      --rpc-url $L2_RPC  # 0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984   (vault)
cast call [new-impl-placeholder] "quotaManager()(address)"  --rpc-url $L2_RPC  # 0x0000000000000000000000000000000000000000   (vault)

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
# First argument of the L2 bridge and vault is the resolver PROXY, not its implementation.
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/bridge/Bridge.sol:Bridge --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address,bool)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x1670000000000000000000000000000000000005 \
    0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 false)
FOUNDRY_PROFILE=layer2 forge verify-bytecode [new-impl-placeholder] \
  contracts/shared/vault/ERC20Vault.sol:ERC20Vault --rpc-url $L2_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address)" \
    0x2ea05A9CD06984Cf533a1829d8b0BE6289a43984 0x0000000000000000000000000000000000000000)

# Simulate both legs against the live chains; both revert with DryrunSucceeded().
cd packages/protocol
MODE=l1dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0025.s.sol:Proposal0025 --rpc-url $L1_RPC
MODE=l2dryrun FOUNDRY_PROFILE=layer1 forge script script/layer1/proposals/Proposal0025.s.sol:Proposal0025 --rpc-url $L2_RPC

# Rehearse the exact batch against live state; both legs must pass. While the fork still predates
# Proposal0024 the rehearsal executes that batch first; while the constants are placeholders it
# builds the implementations from the tree. On L1 it pins the defect on the Proposal0024 code (a
# recall drains the Ether quota, a refund debits the WETH quota), executes the batch, and shows the
# same recalls reverting with B_RECALL_DISABLED afterwards, both quotas untouched, while a real
# withdrawal is still debited. On L2 it delivers the batch through processMessage, then sends,
# delivers bridged USDT and serves a second governance message through the upgraded bridge.
L1_FORK_URL=$L1_RPC L2_FORK_URL=$L2_RPC FOUNDRY_PROFILE=layer1 \
  forge test --match-contract Proposal0025ForkTest -vv
```

The L2 dry run calls `DelegateController.dryrun` directly and so does not exercise the mid-call
self-upgrade; only the fork test does.

## After Execution

- Record both upgrades in `deployments/mainnet-contract-logs-L1.md` and
  `deployments/mainnet-contract-logs-L2.md`.
- Re-read the four implementation slots (first block of [Verification](#verification)) against the
  new addresses, and confirm `recallEnabled()` reads `false` through both bridge proxies.
