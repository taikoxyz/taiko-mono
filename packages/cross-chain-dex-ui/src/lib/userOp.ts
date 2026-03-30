import {
  encodeFunctionData,
  encodeAbiParameters,
  keccak256,
  encodePacked,
  Address,
  Hex,
} from 'viem';
import { UserOp, SwapDirection } from '../types';
import { CrossChainSwapVaultL1ABI, BridgeABI, ERC20ABI, SafeProxyFactoryABI } from './contracts';
import { L1_VAULT, L1_BRIDGE, L2_BRIDGE, L2_CHAIN_ID, CHAIN_ID, USDC_TOKEN, BUILDER_RPC_URL, L2_RELAY, SAFE_PROXY_FACTORY, SAFE_SINGLETON, SAFE_FALLBACK_HANDLER } from './constants';
import { SafeTxParams, buildMultiSendSafeTx, buildSafeSetupCalldata } from './safeOp';

// ---------------------------------------------------------------
// Safe tx conversion
// ---------------------------------------------------------------

/**
 * Convert UserOp[] to a single SafeTxParams.
 * Single op: direct CALL. Multiple ops: wrap in MultiSend DELEGATECALL.
 */
export function userOpsToSafeTx(ops: UserOp[]): SafeTxParams {
  if (ops.length === 1) {
    return {
      to: ops[0].target,
      value: ops[0].value,
      data: ops[0].data,
      operation: 0, // CALL
    };
  }
  // Multiple ops: use MultiSend
  const safeTxs: SafeTxParams[] = ops.map(op => ({
    to: op.target,
    value: op.value,
    data: op.data,
    operation: 0 as const,
  }));
  return buildMultiSendSafeTx(safeTxs);
}

// ---------------------------------------------------------------
// UserOp Builders
// ---------------------------------------------------------------

/**
 * Build UserOp(s) for a swap
 */
export function buildSwapUserOps(
  direction: SwapDirection,
  amountIn: bigint,
  minAmountOut: bigint,
  recipient: Address
): UserOp[] {
  if (direction === 'ETH_TO_USDC') {
    // Single op: call swapETHForToken with value
    return [
      {
        target: L1_VAULT,
        value: amountIn,
        data: encodeFunctionData({
          abi: CrossChainSwapVaultL1ABI,
          functionName: 'swapETHForToken',
          args: [minAmountOut, recipient],
        }),
      },
    ];
  } else {
    // USDC to ETH: need approve + swap
    const usdcAddress = USDC_TOKEN.address;
    if (!usdcAddress) throw new Error('USDC address not configured');

    return [
      // 1. Approve L1Vault to spend USDC
      {
        target: usdcAddress,
        value: 0n,
        data: encodeFunctionData({
          abi: ERC20ABI,
          functionName: 'approve',
          args: [L1_VAULT, amountIn],
        }),
      },
      // 2. Execute swap
      {
        target: L1_VAULT,
        value: 0n,
        data: encodeFunctionData({
          abi: CrossChainSwapVaultL1ABI,
          functionName: 'swapTokenForETH',
          args: [amountIn, minAmountOut, recipient],
        }),
      },
    ];
  }
}

/**
 * Build UserOp(s) for bridging tokens L1→L2
 */
export function buildBridgeUserOps(
  amount: bigint,
  recipient: Address
): UserOp[] {
  const usdcAddress = USDC_TOKEN.address;
  if (!usdcAddress) throw new Error('USDC address not configured');

  return [
    // 1. Approve L1Vault to spend USDC
    {
      target: usdcAddress,
      value: 0n,
      data: encodeFunctionData({
        abi: ERC20ABI,
        functionName: 'approve',
        args: [L1_VAULT, amount],
      }),
    },
    // 2. Bridge tokens to L2
    {
      target: L1_VAULT,
      value: 0n,
      data: encodeFunctionData({
        abi: CrossChainSwapVaultL1ABI,
        functionName: 'bridgeTokenToL2',
        args: [amount, recipient],
      }),
    },
  ];
}

/**
 * Build UserOp(s) for bridging native xDAI from L1 to L2 via the bridge
 */
export function buildBridgeNativeUserOps(
  amount: bigint,
  recipient: Address,
  sender: Address
): UserOp[] {
  const zeroAddr = '0x0000000000000000000000000000000000000000' as Address;

  return [
    {
      target: L1_BRIDGE,
      value: amount,
      data: encodeFunctionData({
        abi: BridgeABI,
        functionName: 'sendMessage',
        args: [
          {
            id: 0n,
            fee: 0n,
            gasLimit: 1_000_000,
            from: zeroAddr,
            srcChainId: 0n,
            srcOwner: sender,
            destChainId: BigInt(L2_CHAIN_ID),
            destOwner: recipient,
            to: recipient,
            value: amount,
            data: '0x',
          },
        ],
      }),
    },
  ];
}

/**
 * Build UserOp(s) for bridging native currency from L2 to L1 via the L2 bridge
 */
export function buildBridgeOutNativeUserOps(
  amount: bigint,
  recipient: Address,
  sender: Address
): UserOp[] {
  const zeroAddr = '0x0000000000000000000000000000000000000000' as Address;

  return [{
    target: L2_BRIDGE,
    value: amount,
    data: encodeFunctionData({
      abi: BridgeABI,
      functionName: 'sendMessage',
      args: [{
        id: 0n,
        fee: 0n,
        gasLimit: 1_000_000,
        from: zeroAddr,
        srcChainId: 0n,
        srcOwner: sender,
        destChainId: BigInt(CHAIN_ID),
        destOwner: recipient,
        to: recipient,
        value: amount,
        data: '0x',
      }],
    }),
  }];
}

/**
 * Build UserOp(s) for adding liquidity to L2 DEX from L1
 */
export function buildAddLiquidityUserOps(
  ethAmount: bigint,
  tokenAmount: bigint
): UserOp[] {
  const usdcAddress = USDC_TOKEN.address;
  if (!usdcAddress) throw new Error('USDC address not configured');

  return [
    // 1. Approve L1Vault to spend USDC
    {
      target: usdcAddress,
      value: 0n,
      data: encodeFunctionData({
        abi: ERC20ABI,
        functionName: 'approve',
        args: [L1_VAULT, tokenAmount],
      }),
    },
    // 2. Add liquidity (sends ETH + locks tokens)
    {
      target: L1_VAULT,
      value: ethAmount,
      data: encodeFunctionData({
        abi: CrossChainSwapVaultL1ABI,
        functionName: 'addLiquidityToL2',
        args: [tokenAmount],
      }),
    },
  ];
}

/**
 * Build UserOp(s) for withdrawing all funds from the Safe to the owner EOA
 */
export function buildWithdrawUserOps(
  owner: Address,
  ethBalance: bigint,
  usdcBalance: bigint
): UserOp[] {
  const ops: UserOp[] = [];

  if (usdcBalance > 0n) {
    const usdcAddress = USDC_TOKEN.address;
    if (usdcAddress) {
      ops.push({
        target: usdcAddress,
        value: 0n,
        data: encodeFunctionData({
          abi: ERC20ABI,
          functionName: 'transfer',
          args: [owner, usdcBalance],
        }),
      });
    }
  }

  if (ethBalance > 0n) {
    ops.push({
      target: owner,
      value: ethBalance,
      data: '0x',
    });
  }

  return ops;
}

/**
 * Build UserOp(s) for removing all liquidity from L2 DEX
 */
export function buildRemoveLiquidityUserOps(): UserOp[] {
  return [
    {
      target: L1_VAULT,
      value: 0n,
      data: encodeFunctionData({
        abi: CrossChainSwapVaultL1ABI,
        functionName: 'removeLiquidityFromL2',
        args: [],
      }),
    },
  ];
}

/**
 * Build UserOp(s) for creating a Safe on L2 via bridge + relay.
 * The L1 Safe calls bridge.sendMessage targeting the CrossChainRelay on L2,
 * which forwards to SafeProxyFactory.createProxyWithNonce.
 */
export function buildCreateL2SafeOps(owner: Address, sender: Address): UserOp[] {
  const zeroAddr = '0x0000000000000000000000000000000000000000' as Address;

  // Build the same initializer and saltNonce as L1 creation
  const initializer = buildSafeSetupCalldata(owner, SAFE_FALLBACK_HANDLER);
  const saltNonce = BigInt(keccak256(encodePacked(['address'], [owner])));

  // The call the relay will forward to the factory
  const createProxyCalldata = encodeFunctionData({
    abi: SafeProxyFactoryABI,
    functionName: 'createProxyWithNonce',
    args: [SAFE_SINGLETON, initializer, saltNonce],
  });

  // Encode for relay: abi.encode(target, callData)
  const relayPayload = encodeAbiParameters(
    [{ type: 'address' }, { type: 'bytes' }],
    [SAFE_PROXY_FACTORY, createProxyCalldata],
  );

  // Bridge requires onMessageInvocation selector
  const onMessageInvocationData = encodeFunctionData({
    abi: [{
      type: 'function',
      name: 'onMessageInvocation',
      inputs: [{ name: '_data', type: 'bytes' }],
      outputs: [],
      stateMutability: 'payable',
    }],
    functionName: 'onMessageInvocation',
    args: [relayPayload],
  });

  return [{
    target: L1_BRIDGE,
    value: 0n,
    data: encodeFunctionData({
      abi: BridgeABI,
      functionName: 'sendMessage',
      args: [{
        id: 0n,
        fee: 0n,
        gasLimit: 2_000_000,
        from: zeroAddr,
        srcChainId: 0n,
        srcOwner: sender,
        destChainId: BigInt(L2_CHAIN_ID),
        destOwner: sender,
        to: L2_RELAY,
        value: 0n,
        data: onMessageInvocationData,
      }],
    }),
  }];
}

// ---------------------------------------------------------------
// Builder RPC
// ---------------------------------------------------------------

/**
 * Get the builder RPC URL (use proxy in development to avoid CORS)
 */
function getBuilderUrl(): string {
  // Always use Vite proxy in dev to avoid CORS issues
  if (import.meta.env.DEV) {
    return '/api/builder';
  }
  return BUILDER_RPC_URL;
}

/**
 * Send UserOp to builder RPC
 */
export async function sendUserOpToBuilder(
  submitter: Address,
  calldata: Hex,
  chainId?: number
): Promise<{ success: boolean; result?: unknown; error?: string; userOpId?: number }> {
  try {
    const builderUrl = getBuilderUrl();
    console.log('Sending UserOp to:', builderUrl);
    console.log('Submitter:', submitter);
    console.log('ChainId:', chainId);

    const response = await fetch(builderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'surge_sendUserOp',
        params: {
          submitter,
          calldata,
          ...(chainId ? { chainId } : {}),
        },
        id: 1,
      }),
    });

    // Check if response is ok
    if (!response.ok) {
      const text = await response.text();
      console.error('Builder RPC error:', response.status, text);
      return { success: false, error: `Builder RPC error: ${response.status} - ${text || 'No response'}` };
    }

    // Check if response has content
    const text = await response.text();
    if (!text) {
      console.error('Builder RPC returned empty response');
      return { success: false, error: 'Builder RPC returned empty response. Is the builder running?' };
    }

    // Parse JSON
    let json;
    try {
      json = JSON.parse(text);
    } catch {
      console.error('Failed to parse builder response:', text);
      return { success: false, error: `Invalid JSON response: ${text.slice(0, 100)}` };
    }

    console.log('Builder response:', json);

    if (json.error) {
      return { success: false, error: json.error.message || JSON.stringify(json.error) };
    }

    const userOpId = typeof json.result === 'number' ? json.result : undefined;
    return { success: true, result: json.result, userOpId };
  } catch (error) {
    console.error('sendUserOpToBuilder error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to send UserOp',
    };
  }
}

export type UserOpStatus =
  | { status: 'Pending' }
  | { status: 'Processing'; tx_hash: string }
  | { status: 'ProvingBlock'; block_id: number }
  | { status: 'Rejected'; reason: string }
  | { status: 'Executed' };

/**
 * Query the status of a submitted UserOp by ID
 */
export async function queryUserOpStatus(userOpId: number): Promise<UserOpStatus | null> {
  try {
    const builderUrl = getBuilderUrl();
    const response = await fetch(builderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'surge_userOpStatus',
        params: [userOpId],
        id: 1,
      }),
    });

    if (!response.ok) return null;

    const text = await response.text();
    if (!text) return null;

    const json = JSON.parse(text);
    if (json.error) return null;

    return json.result as UserOpStatus;
  } catch {
    return null;
  }
}

/**
 * Calculate output amount using DEX formula (client-side)
 * amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
 */
export function calculateAmountOut(
  amountIn: bigint,
  reserveIn: bigint,
  reserveOut: bigint
): bigint {
  if (amountIn === 0n || reserveIn === 0n || reserveOut === 0n) {
    return 0n;
  }

  const amountInWithFee = amountIn * 997n;
  const numerator = amountInWithFee * reserveOut;
  const denominator = reserveIn * 1000n + amountInWithFee;

  return numerator / denominator;
}

/**
 * Calculate minimum output with slippage
 */
export function calculateMinOutput(amountOut: bigint, slippagePercent: number): bigint {
  const slippageBps = BigInt(Math.floor(slippagePercent * 100)); // Convert to basis points
  const minOutput = (amountOut * (10000n - slippageBps)) / 10000n;
  return minOutput;
}
