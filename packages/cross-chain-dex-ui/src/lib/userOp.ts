import {
  encodeFunctionData,
  encodeAbiParameters,
  keccak256,
  Address,
  Hex,
  hexToBytes,
} from 'viem';
import { UserOp, SwapDirection } from '../types';
import { CrossChainSwapVaultL1ABI, BridgeABI, ERC20ABI, UserOpsSubmitterABI } from './contracts';
import { L1_VAULT, L1_BRIDGE, L2_CHAIN_ID, USDC_TOKEN, BUILDER_RPC_URL } from './constants';

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
            gasLimit: 0,
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
 * Compute the digest for signing UserOps
 * This matches: keccak256(abi.encode(ops))
 */
export function computeUserOpsDigest(ops: UserOp[]): Hex {
  const encoded = encodeAbiParameters(
    [
      {
        type: 'tuple[]',
        components: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    [ops.map((op) => ({ target: op.target, value: op.value, data: op.data }))]
  );

  return keccak256(encoded);
}

/**
 * Convert hex string to byte array for RPC
 */
export function hexToByteArray(hex: Hex): number[] {
  return Array.from(hexToBytes(hex));
}

/**
 * Get the builder RPC URL (use proxy in development to avoid CORS)
 */
function getBuilderUrl(): string {
  // Use proxy in development to avoid CORS issues
  if (BUILDER_RPC_URL.includes('localhost') && typeof window !== 'undefined' && window.location.hostname === 'localhost') {
    return '/api/builder';
  }
  return BUILDER_RPC_URL;
}

/**
 * Send UserOp to builder RPC
 */
export async function sendUserOpToBuilder(
  submitter: Address,
  ops: UserOp[],
  signature: Hex
): Promise<{ success: boolean; result?: unknown; error?: string; userOpId?: number }> {
  try {
    const builderUrl = getBuilderUrl();
    console.log('Sending UserOp to:', builderUrl);
    console.log('Submitter:', submitter);
    console.log('Ops count:', ops.length);

    // Encode the full executeBatch(ops, signature) calldata
    const calldata = encodeFunctionData({
      abi: UserOpsSubmitterABI,
      functionName: 'executeBatch',
      args: [
        ops.map((op) => ({ target: op.target, value: op.value, data: op.data })),
        signature,
      ],
    });

    const response = await fetch(builderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'surge_sendUserOp',
        params: {
          submitter,
          calldata,
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
    } catch (parseError) {
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
