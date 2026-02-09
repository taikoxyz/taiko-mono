import {
  encodeFunctionData,
  encodeAbiParameters,
  keccak256,
  toHex,
  Address,
  Hex,
  hexToBytes,
} from 'viem';
import { UserOp, SwapDirection } from '../types';
import { CrossChainSwapHandlerL1ABI, ERC20ABI } from './contracts';
import { L1_HANDLER, USDC_TOKEN, BUILDER_RPC_URL } from './constants';

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
    // Single op: call swapETHForERC20 with value
    return [
      {
        target: L1_HANDLER,
        value: amountIn,
        data: encodeFunctionData({
          abi: CrossChainSwapHandlerL1ABI,
          functionName: 'swapETHForERC20',
          args: [minAmountOut, recipient],
        }),
      },
    ];
  } else {
    // USDC to ETH: need approve + swap
    const usdcAddress = USDC_TOKEN.address;
    if (!usdcAddress) throw new Error('USDC address not configured');

    return [
      // 1. Approve L1Handler to spend USDC
      {
        target: usdcAddress,
        value: 0n,
        data: encodeFunctionData({
          abi: ERC20ABI,
          functionName: 'approve',
          args: [L1_HANDLER, amountIn],
        }),
      },
      // 2. Execute swap
      {
        target: L1_HANDLER,
        value: 0n,
        data: encodeFunctionData({
          abi: CrossChainSwapHandlerL1ABI,
          functionName: 'swapERC20ForETH',
          args: [amountIn, minAmountOut, recipient],
        }),
      },
    ];
  }
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
): Promise<{ success: boolean; result?: unknown; error?: string }> {
  try {
    const builderUrl = getBuilderUrl();
    console.log('Sending UserOps to:', builderUrl);
    console.log('UserOps:', ops.map((op) => ({ target: op.target, value: op.value.toString() })));

    const response = await fetch(builderUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'surge_sendUserOp',
        params: {
          submitter,
          user_ops: ops.map((op) => ({
            target: op.target,
            value: toHex(op.value),
            data: op.data,
          })),
          signature: hexToByteArray(signature),
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

    return { success: true, result: json.result };
  } catch (error) {
    console.error('sendUserOpToBuilder error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to send UserOp',
    };
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
