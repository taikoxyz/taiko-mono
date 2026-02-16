# Cross-Chain DEX POC

A proof-of-concept demonstrating cross-chain token swaps, bridging, and liquidity provisioning between L1 and L2 on Taiko's based rollup. The native token is xDAI (Gnosis).

## Architecture Overview

```
L1 (Gnosis Chain)                              L2 (Taiko Rollup)
┌─────────────────────────┐                    ┌──────────────────────────┐
│  SwapToken (USDC)       │                    │  SwapTokenL2 (bUSDC)     │
│  canonical ERC20        │                    │  mint/burn by L2 vault   │
├─────────────────────────┤                    ├──────────────────────────┤
│                         │   IBridge          │                          │
│  CrossChainSwapVaultL1  │◄──────────────────►│  CrossChainSwapVaultL2   │
│  lock/release tokens    │   sendMessage()    │  mint/burn + DEX calls   │
│  send/receive xDAI      │   onMessageInv()   │                          │
├─────────────────────────┤                    ├──────────────────────────┤
│                         │                    │  SimpleDEX               │
│  UserOpsSubmitter       │                    │  x*y=k AMM (0.3% fee)   │
│  batch exec + sig check │                    │  xDAI / bUSDC pair       │
└─────────────────────────┘                    └──────────────────────────┘
         ▲
         │ surge_sendUserOp (JSON-RPC)
         │
    Builder RPC
         ▲
         │ sign + submit
         │
    Browser UI (Vite + React)
```

### Core Idea

1. **Canonical tokens live on L1.** The L1 vault locks them when bridging or swapping.
2. **L2 has bridged representations.** The L2 vault mints/burns them via `SwapTokenL2`.
3. **The DEX lives on L2.** A constant-product AMM (`SimpleDEX`) handles xDAI/USDC swaps.
4. **The bridge carries messages.** Each operation is one or two bridge messages — the vaults encode an `Action` enum in the message data and the receiving vault decodes and routes it.
5. **UserOps provide account abstraction.** Users sign a batch of operations, the builder executes them on-chain via their `UserOpsSubmitter` smart wallet.

---

## Contracts

### L1 Contracts

| Contract                | File                                                                                                                                                     | Role                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `SwapToken`             | [`contracts/layer1/surge/cross-chain-dex/SwapToken.sol`](packages/protocol/contracts/layer1/surge/cross-chain-dex/SwapToken.sol)                         | Canonical ERC20 on L1. Only the designated minter can mint.                      |
| `CrossChainSwapVaultL1` | [`contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol) | Unified vault: locks tokens, sends bridge messages, handles completions from L2. |

### L2 Contracts

| Contract                | File                                                                                                                                                     | Role                                                                                               |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `SwapTokenL2`           | [`contracts/layer2/surge/cross-chain-dex/SwapTokenL2.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/SwapTokenL2.sol)                     | Bridged ERC20 with configurable decimals. Minter authority transferred to L2 vault at deploy time. |
| `SimpleDEX`             | [`contracts/layer2/surge/cross-chain-dex/SimpleDEX.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/SimpleDEX.sol)                         | UniV2-style AMM for xDAI/USDC with 0.3% fee.                                                       |
| `CrossChainSwapVaultL2` | [`contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol) | Receives bridge messages, mints/burns tokens, interacts with DEX, sends completions back to L1.    |

### Shared Contracts

| Contract                  | File                                                                                                                             | Role                                                                   |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `IBridge`                 | [`contracts/shared/bridge/IBridge.sol`](packages/protocol/contracts/shared/bridge/IBridge.sol)                                   | Bridge interface used by vaults to send/receive cross-chain messages.  |
| `UserOpsSubmitter`        | [`contracts/shared/userops/UserOpsSubmitter.sol`](packages/protocol/contracts/shared/userops/UserOpsSubmitter.sol)               | Smart wallet that verifies signatures and executes batched operations. |
| `UserOpsSubmitterFactory` | [`contracts/shared/userops/UserOpsSubmitterFactory.sol`](packages/protocol/contracts/shared/userops/UserOpsSubmitterFactory.sol) | Deploys one `UserOpsSubmitter` per EOA.                                |

---

## The Action Enum

Both vaults share this enum to route behavior from a single `onMessageInvocation` callback:

```solidity
enum Action {
    BRIDGE,              // L1→L2: mint bridged tokens to recipient
    SWAP_ETH_TO_TOKEN,   // L1→L2→L1: swap xDAI for USDC
    SWAP_TOKEN_TO_ETH,   // L1→L2→L1: swap USDC for xDAI
    ADD_LIQUIDITY        // L1→L2: add xDAI+USDC to DEX pool
}
```

See: [`CrossChainSwapVaultL1.sol:20-25`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L20-L25)

---

## Message Flows

### 1. Bridge USDC (L1 → L2) — 1 message

```
User → L1 Vault: bridgeTokenToL2(amount, recipient)
  │  Locks canonical tokens in vault
  │
  ├─── Bridge Message ──► L2 Vault: onMessageInvocation
  │                          │  Decodes Action.BRIDGE
  │                          │  Mints bridged tokens to recipient
  │                          ▼
  │                        Done (1 message total)
```

See: [`CrossChainSwapVaultL1.sol:91-102`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L91-L102) and [`CrossChainSwapVaultL2.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol) `_handleBridge`.

### 2. Bridge xDAI (L1 → L2) — 1 message

```
User → L1 Bridge: sendMessage({to: recipient, value: amount, data: 0x})
  │  Bridge holds xDAI
  │
  ├─── Bridge Message ──► Recipient receives xDAI on L2
  │
  │                        Done (1 message total)
```

This uses the bridge directly (no vault needed). See: [`userOp.ts:102-134`](packages/cross-chain-dex-ui/src/lib/userOp.ts#L102-L134) `buildBridgeNativeUserOps`.

### 3. Swap xDAI → USDC (L1 → L2 → L1) — 2 messages

```
User → L1 Vault: swapETHForToken{value: xDAI}(minTokenOut, recipient)
  │  Sends xDAI to L2 via bridge
  │
  ├─── Message 1 (with xDAI value) ──► L2 Vault: onMessageInvocation
  │                                       │  Decodes SWAP_ETH_TO_TOKEN
  │                                       │  Calls DEX.swapETHForToken (xDAI → bUSDC)
  │                                       │  Burns received bUSDC tokens
  │                                       │
  │    ◄── Message 2 (completion) ────────┤  Sends completion with token amount
  │                                       ▼
  │  L1 Vault: onMessageInvocation
  │  Decodes SWAP_ETH_TO_TOKEN
  │  Releases canonical USDC to recipient
  ▼
Done (2 messages total)
```

See L1 initiation: [`CrossChainSwapVaultL1.sol:111-125`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L111-L125). L2 handling: [`CrossChainSwapVaultL2.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol) `_handleSwapETHToToken`. L1 completion: [`CrossChainSwapVaultL1.sol:186-191`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L186-L191).

### 4. Swap USDC → xDAI (L1 → L2 → L1) — 2 messages

```
User → L1 Vault: swapTokenForETH(tokenAmount, minETHOut, recipient)
  │  Locks canonical USDC in vault
  │
  ├─── Message 1 ──► L2 Vault: onMessageInvocation
  │                     │  Decodes SWAP_TOKEN_TO_ETH
  │                     │  Mints bUSDC tokens
  │                     │  Calls DEX.swapTokenForETH (bUSDC → xDAI)
  │                     │
  │  ◄── Message 2 ────┤  Sends xDAI back to L1 vault
  │      (with xDAI)   ▼
  │
  │  L1 Vault: onMessageInvocation
  │  Forwards xDAI to recipient
  ▼
Done (2 messages total)
```

See L1 initiation: [`CrossChainSwapVaultL1.sol:135-152`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L135-L152). L1 completion: [`CrossChainSwapVaultL1.sol:192-200`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L192-L200).

### 5. Add Liquidity (L1 → L2) — 1 message

```
User → L1 Vault: addLiquidityToL2{value: xDAI}(tokenAmount)
  │  Locks canonical USDC, sends xDAI to L2
  │
  ├─── Message (with xDAI) ──► L2 Vault: onMessageInvocation
  │                               │  Decodes ADD_LIQUIDITY
  │                               │  Mints bUSDC tokens
  │                               │  Calls DEX.addLiquidity{value: xDAI}(tokenAmount)
  │                               ▼
  │                             Done (1 message total)
```

See: [`CrossChainSwapVaultL1.sol:160-171`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L160-L171).

---

## How Bridge Messages Work

### Sending a Message

The vault constructs an `IBridge.Message` struct and calls `bridge.sendMessage`:

```solidity
// From CrossChainSwapVaultL1._sendMessageToL2()
bytes memory msgData = abi.encodeWithSignature("onMessageInvocation(bytes)", _innerData);

IBridge.Message memory message = IBridge.Message({
    id: 0,              // auto-assigned by bridge
    fee: 0,             // no relayer fee (POC)
    gasLimit: 1_000_000, // gas for L2 execution
    from: address(0),    // auto-assigned by bridge
    srcChainId: 0,       // auto-assigned by bridge
    srcOwner: msg.sender,
    destChainId: l2ChainId,
    destOwner: l2Vault,
    to: l2Vault,
    value: _ethValue,    // xDAI to transfer
    data: msgData        // encoded callback
});

IBridge(bridge).sendMessage{ value: _ethValue }(message);
```

See: [`CrossChainSwapVaultL1.sol:208-227`](packages/protocol/contracts/layer1/surge/cross-chain-dex/CrossChainSwapVaultL1.sol#L208-L227)

**Key point:** `data` must start with the `onMessageInvocation(bytes)` selector. The bridge calls `to.onMessageInvocation(innerData)` on the destination chain.

### Receiving a Message

The receiving vault implements `onMessageInvocation(bytes calldata _data)` and verifies the message origin:

```solidity
function onMessageInvocation(bytes calldata _data) external payable {
    if (msg.sender != bridge) revert ONLY_BRIDGE();

    IBridge.Context memory ctx = IBridge(bridge).context();
    if (ctx.from != l1Vault) revert INVALID_SENDER();

    Action action = abi.decode(_data, (Action));
    // route to handler based on action...
}
```

See: [`CrossChainSwapVaultL2.sol`](packages/protocol/contracts/layer2/surge/cross-chain-dex/CrossChainSwapVaultL2.sol) `onMessageInvocation`.

### Verification Pattern

Every `onMessageInvocation` must:

1. Check `msg.sender == bridge` (only the bridge can call)
2. Check `IBridge(bridge).context().from == expectedSender` (only the paired vault originated it)

This prevents spoofed messages.

---

## UserOps (Account Abstraction)

Users don't send transactions directly. Instead:

1. The UI builds an array of `UserOp` structs (target, value, calldata)
2. Computes `digest = keccak256(abi.encode(ops))`
3. User signs the digest with their EOA (`personal_sign`)
4. Sends `{submitter, calldata}` to the builder via `surge_sendUserOp` JSON-RPC
5. The builder submits the transaction on-chain, calling `UserOpsSubmitter.executeBatch(ops, signature)`
6. The submitter contract verifies the signature matches the owner and executes each op

### Example: USDC → xDAI Swap (2 UserOps)

```typescript
// From userOp.ts buildSwapUserOps()
const ops = [
  {
    target: usdcAddress, // 1. Approve vault to spend USDC
    value: 0n,
    data: encodeFunctionData({
      abi: ERC20ABI,
      functionName: "approve",
      args: [L1_VAULT, amountIn],
    }),
  },
  {
    target: L1_VAULT, // 2. Execute swap
    value: 0n,
    data: encodeFunctionData({
      abi: VaultABI,
      functionName: "swapTokenForETH",
      args: [amountIn, minOut, recipient],
    }),
  },
];
```

See: [`userOp.ts:16-63`](packages/cross-chain-dex-ui/src/lib/userOp.ts#L16-L63)

### Builder RPC

The builder exposes two methods:

| Method               | Params                                  | Returns                                                                  |
| -------------------- | --------------------------------------- | ------------------------------------------------------------------------ |
| `surge_sendUserOp`   | `{ submitter: address, calldata: hex }` | `userOpId: number`                                                       |
| `surge_userOpStatus` | `[userOpId]`                            | `{ status: "Pending" \| "Processing" \| "Executed" \| "Rejected", ... }` |

See: [`userOp.ts:176-286`](packages/cross-chain-dex-ui/src/lib/userOp.ts#L176-L286)

---

## SimpleDEX AMM

The DEX uses the constant product formula with a 0.3% fee:

```
amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
```

See: [`SimpleDEX.sol:150-167`](packages/protocol/contracts/layer2/surge/cross-chain-dex/SimpleDEX.sol#L150-L167)

Access control:

- `addLiquidity`: restricted to `admin` or `liquidityProvider` (the L2 vault)
- `swapETHForToken` / `swapTokenForETH`: open to anyone (but in practice only the L2 vault calls them)

---

## Deployment

### Deploy Scripts

| Script    | File                                                                                                                 |
| --------- | -------------------------------------------------------------------------------------------------------------------- |
| L1 deploy | [`DeployCrossChainDexL1.s.sol`](packages/protocol/script/layer1/surge/cross-chain-dex/DeployCrossChainDexL1.s.sol)   |
| L2 deploy | [`DeployCrossChainDexL2.s.sol`](packages/protocol/script/layer2/surge/cross-chain-dex/DeployCrossChainDexL2.s.sol)   |
| L1 setup  | [`SetupCrossChainDex.s.sol`](packages/protocol/script/layer1/surge/cross-chain-dex/SetupCrossChainDex.s.sol)         |
| L2 setup  | [`SetupCrossChainDexL2.s.sol`](packages/protocol/script/layer2/surge/cross-chain-dex/SetupCrossChainDexL2.s.sol)     |
| L1 shell  | [`deploy_cross_chain_dex_l1.sh`](packages/protocol/script/layer1/surge/cross-chain-dex/deploy_cross_chain_dex_l1.sh) |
| L2 shell  | [`deploy_cross_chain_dex_l2.sh`](packages/protocol/script/layer2/surge/cross-chain-dex/deploy_cross_chain_dex_l2.sh) |

### Using an Existing L1 Token (e.g. Real USDC)

By default, the L1 deploy script creates a new `SwapToken`. To use an existing token (like real USDC on Gnosis), set the `SWAP_TOKEN` env var:

```bash
# Deploy L1 vault with real Gnosis USDC (skips SwapToken deployment)
SWAP_TOKEN=0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83 \
  BROADCAST=true ./script/layer1/surge/cross-chain-dex/deploy_cross_chain_dex_l1.sh
```

When `SWAP_TOKEN` is set, the script skips deploying a new token and uses the existing one as the canonical L1 token for the vault.

**Important: matching decimals.** The L2 `SwapTokenL2` must use the same decimal count as the L1 token. Real USDC uses 6 decimals, so the L2 deploy script deploys `SwapTokenL2` with 6 decimals. If you use a different token, update the decimals in `DeployCrossChainDexL2.s.sol` accordingly. Raw token amounts pass through the bridge unchanged, so a mismatch would cause incorrect balances.

### Deployment Order

```bash
# 1. Deploy L1 (SwapToken + VaultL1)
#    Set SWAP_TOKEN=0x... to use an existing L1 token instead of deploying a new one
BROADCAST=true ./script/layer1/surge/cross-chain-dex/deploy_cross_chain_dex_l1.sh

# 2. Deploy L2 (SwapTokenL2 + SimpleDEX + VaultL2)
#    Automatically transfers minter to vault and sets vault as DEX liquidity provider
#    SwapTokenL2 decimals must match the L1 token (default: 6 for USDC)
BROADCAST=true ./script/layer2/surge/cross-chain-dex/deploy_cross_chain_dex_l2.sh

# 3. Link vaults
cast send <L1_VAULT> "setL2Vault(address)" <L2_VAULT> --rpc-url <L1_RPC> --private-key <KEY>
cast send <L2_VAULT> "setL1Vault(address)" <L1_VAULT> --rpc-url <L2_RPC> --private-key <KEY>

# 4. Add initial liquidity from L1
cast send <USDC> "approve(address,uint256)" <L1_VAULT> <TOKEN_AMOUNT> --rpc-url <L1_RPC> --private-key <KEY>
cast send <L1_VAULT> "addLiquidityToL2(uint256)" <TOKEN_AMOUNT> --value <XDAI_AMOUNT> --rpc-url <L1_RPC> --private-key <KEY>
```

### Environment Variables

```bash
# Deploy scripts
PRIVATE_KEY=0x...
L1_RPC=http://...
L2_RPC=http://...
L1_BRIDGE=0x...
L2_BRIDGE=0x...
SWAP_TOKEN=0x...           # (optional) existing L1 token address — skips SwapToken deployment

# UI (.env)
VITE_L1_RPC_URL=http://...
VITE_L2_RPC_URL=http://...
VITE_BUILDER_RPC_URL=http://localhost:4545
VITE_CHAIN_ID=3151908
VITE_USER_OPS_FACTORY=0x...
VITE_L1_VAULT=0x...
VITE_USDC_TOKEN=0x...
VITE_SIMPLE_DEX=0x...
VITE_L1_BRIDGE=0x...
VITE_L2_CHAIN_ID=763374
```

---

## Running the UI

```bash
cd packages/cross-chain-dex-ui

# Install dependencies
pnpm install

# Copy and fill in .env
cp .env.example .env
# Edit .env with your contract addresses and RPC URLs

# Start dev server
pnpm dev
# → http://localhost:5173/
```

Vite bakes env vars at build time — restart the dev server after changing `.env`.

Prerequisites:

- The builder RPC must be running at the URL specified in `VITE_BUILDER_RPC_URL`
- MetaMask (or any injected wallet) must be configured with the L1 chain

---

## UI

The frontend is a Vite + React app in [`packages/cross-chain-dex-ui/`](packages/cross-chain-dex-ui/).

| Component       | File                                                                                | Purpose                                                    |
| --------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `SwapCard`      | [`SwapCard.tsx`](packages/cross-chain-dex-ui/src/components/SwapCard.tsx)           | xDAI/USDC swap interface                                   |
| `LiquidityCard` | [`LiquidityCard.tsx`](packages/cross-chain-dex-ui/src/components/LiquidityCard.tsx) | Add liquidity (with initial price setting for empty pools) |
| `BridgeCard`    | [`BridgeCard.tsx`](packages/cross-chain-dex-ui/src/components/BridgeCard.tsx)       | Bridge xDAI or USDC from L1 to L2                          |

Key libraries:
| File | Purpose |
|------|---------|
| [`userOp.ts`](packages/cross-chain-dex-ui/src/lib/userOp.ts) | Builds UserOp arrays for each action, signs, sends to builder |
| [`contracts.ts`](packages/cross-chain-dex-ui/src/lib/contracts.ts) | ABI definitions for all contracts |
| [`constants.ts`](packages/cross-chain-dex-ui/src/lib/constants.ts) | Token definitions, contract addresses, RPC URLs |
| [`useUserOp.ts`](packages/cross-chain-dex-ui/src/hooks/useUserOp.ts) | React hook: sign, submit, poll status |
| [`useDexReserves.ts`](packages/cross-chain-dex-ui/src/hooks/useDexReserves.ts) | Polls L2 DEX reserves |
| [`useSwapQuote.ts`](packages/cross-chain-dex-ui/src/hooks/useSwapQuote.ts) | Client-side AMM quote calculation |

---

## Building Your Own Cross-Chain App

To build an arbitrary cross-chain application on this stack, follow this pattern:

### Step 1: Define Your Actions

Add actions to the `Action` enum in both L1 and L2 vault contracts:

```solidity
enum Action {
    // your custom actions
    MY_ACTION,
    MY_OTHER_ACTION
}
```

### Step 2: Implement L1 Entry Points

Add public functions on your L1 contract that:

1. Accept user funds (lock tokens, receive xDAI)
2. Encode the action + params: `abi.encode(Action.MY_ACTION, param1, param2)`
3. Send a bridge message using `_sendMessageToL2(data, ethValue)`

```solidity
function myAction(uint256 _param) external payable {
    // 1. Accept funds
    token.safeTransferFrom(msg.sender, address(this), _param);

    // 2. Encode
    bytes memory data = abi.encode(Action.MY_ACTION, msg.sender, _param);

    // 3. Send
    _sendMessageToL2(data, msg.value);
}
```

### Step 3: Implement L2 Message Handler

In your L2 contract's `onMessageInvocation`, decode the action and execute:

```solidity
function onMessageInvocation(bytes calldata _data) external payable {
    // Verify origin
    if (msg.sender != bridge) revert ONLY_BRIDGE();
    if (IBridge(bridge).context().from != l1Contract) revert INVALID_SENDER();

    Action action = abi.decode(_data, (Action));

    if (action == Action.MY_ACTION) {
        (, address user, uint256 param) = abi.decode(_data, (Action, address, uint256));
        // Do something on L2...

        // Optionally send a completion message back to L1
        bytes memory completion = abi.encode(Action.MY_ACTION, user, result);
        _sendMessageToL1(completion, ethToSendBack);
    }
}
```

### Step 4: Handle Completions on L1 (if needed)

If your L2 action sends a message back, handle it in the L1 `onMessageInvocation`:

```solidity
function onMessageInvocation(bytes calldata _data) external payable {
    if (msg.sender != bridge) revert ONLY_BRIDGE();
    if (IBridge(bridge).context().from != l2Contract) revert INVALID_SENDER();

    Action action = abi.decode(_data, (Action));

    if (action == Action.MY_ACTION) {
        (, address user, uint256 result) = abi.decode(_data, (Action, address, uint256));
        // Release funds, transfer tokens, etc.
    }
}
```

### Step 5: Build UI UserOps

In the frontend, build `UserOp[]` arrays that call your L1 contract:

```typescript
function buildMyActionUserOps(param: bigint): UserOp[] {
  return [
    {
      target: MY_L1_CONTRACT,
      value: 0n,
      data: encodeFunctionData({
        abi: MyContractABI,
        functionName: "myAction",
        args: [param],
      }),
    },
  ];
}
```

Then use the existing `executeGenericOps` pattern from [`useUserOp.ts`](packages/cross-chain-dex-ui/src/hooks/useUserOp.ts) to sign, submit, and poll.

### Key Rules

1. **Bridge messages must use `onMessageInvocation(bytes)`** — the bridge only calls this selector on the destination contract.
2. **Always verify `msg.sender == bridge` and `context().from == expectedSender`** — this is your authentication.
3. **1 message = 1 hop.** If your operation needs a round-trip (L1→L2→L1), that's 2 messages minimum.
4. **xDAI transfers use `message.value`.** Set `value` in the bridge message and send it with `sendMessage{value: amount}`.
5. **Token transfers require lock/mint.** Lock canonical tokens on L1, mint bridged representations on L2. Reverse on the way back.
6. **UserOps are batched atomically.** If any op in the batch fails, all revert. Use this for approve+action patterns.

---

## POC Limitations

- **No nonce on UserOpsSubmitter** — vulnerable to replay attacks. Add nonce checks for production.
- **No pause mechanism** — add `Pausable` for emergency stops.
- **Single liquidity provider** — the L2 vault is the only authorized LP. Extend for permissionless LP.
- **Fixed gas limit** — `GAS_LIMIT = 1_000_000` is hardcoded. Make it configurable.
- **No fee collection** — swap fees accumulate in DEX reserves with no withdrawal mechanism.
- **No message failure handling** — if a bridge message fails on L2, locked L1 funds need a recall mechanism (the bridge supports `RECALLED` status but the vaults don't implement it yet).
