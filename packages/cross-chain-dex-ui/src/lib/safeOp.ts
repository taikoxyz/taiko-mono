import {
  encodeFunctionData,
  encodePacked,
  concat,
  type Address,
  type Hex,
  type PublicClient,
  size,
} from 'viem';
import { SafeABI, MultiSendABI } from './contracts';
import { SAFE_MULTISEND, SAFE_FALLBACK_HANDLER } from './constants';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SafeTxParams {
  to: Address;
  value: bigint;
  data: Hex;
  operation: 0 | 1; // 0 = CALL, 1 = DELEGATECALL
}

// EIP-712 domain for Safe (no name/version fields per Safe spec)
export interface SafeDomain {
  chainId: number;
  verifyingContract: Address;
}

// ---------------------------------------------------------------------------
// Safe EIP-712 type definitions
// ---------------------------------------------------------------------------

export const SafeTxTypes = {
  SafeTx: [
    { name: 'to', type: 'address' },
    { name: 'value', type: 'uint256' },
    { name: 'data', type: 'bytes' },
    { name: 'operation', type: 'uint8' },
    { name: 'safeTxGas', type: 'uint256' },
    { name: 'baseGas', type: 'uint256' },
    { name: 'gasPrice', type: 'uint256' },
    { name: 'gasToken', type: 'address' },
    { name: 'refundReceiver', type: 'address' },
    { name: 'nonce', type: 'uint256' },
  ],
} as const;

// ---------------------------------------------------------------------------
// 1. getSafeDomain
// ---------------------------------------------------------------------------

/**
 * Returns the EIP-712 domain for a deployed Safe.
 * Per the Safe spec the domain has no `name` or `version` fields.
 */
export function getSafeDomain(safeAddress: Address, chainId: number): SafeDomain {
  return {
    chainId,
    verifyingContract: safeAddress,
  };
}

// ---------------------------------------------------------------------------
// 2. buildSafeTxTypedData
// ---------------------------------------------------------------------------

/**
 * Builds the full `signTypedData` params for a single SafeTx.
 * For a 1-of-1 Safe with no gas refund all gas-related fields are 0 /
 * zero-address.
 */
export function buildSafeTxTypedData(
  safeAddress: Address,
  chainId: number,
  nonce: bigint,
  tx: SafeTxParams,
) {
  const domain = getSafeDomain(safeAddress, chainId);

  const message = {
    to: tx.to,
    value: tx.value,
    data: tx.data,
    operation: tx.operation,
    safeTxGas: 0n,
    baseGas: 0n,
    gasPrice: 0n,
    gasToken: '0x0000000000000000000000000000000000000000' as Address,
    refundReceiver: '0x0000000000000000000000000000000000000000' as Address,
    nonce,
  };

  return {
    domain,
    types: SafeTxTypes,
    primaryType: 'SafeTx' as const,
    message,
  };
}

// ---------------------------------------------------------------------------
// 3. buildExecTransactionCalldata
// ---------------------------------------------------------------------------

/**
 * Encodes the `execTransaction` calldata for a Safe.
 * `signature` is the compact EIP-712 signature bytes produced by the owner.
 */
export function buildExecTransactionCalldata(tx: SafeTxParams, signature: Hex): Hex {
  return encodeFunctionData({
    abi: SafeABI,
    functionName: 'execTransaction',
    args: [
      tx.to,
      tx.value,
      tx.data,
      tx.operation,
      0n, // safeTxGas
      0n, // baseGas
      0n, // gasPrice
      '0x0000000000000000000000000000000000000000', // gasToken
      '0x0000000000000000000000000000000000000000', // refundReceiver
      signature,
    ],
  });
}

// ---------------------------------------------------------------------------
// 4. encodeMultiSend
// ---------------------------------------------------------------------------

/**
 * Packs multiple transactions into the byte-string expected by the MultiSend
 * contract.
 *
 * Each tx is encoded as:
 *   uint8 operation | address to | uint256 value | uint256 dataLength | bytes data
 *
 * `size(data)` from viem returns the byte-length of a hex-encoded `Hex` value
 * (i.e. `(data.length - 2) / 2`), correctly returning 0 for `'0x'`.
 */
export function encodeMultiSend(txs: SafeTxParams[]): Hex {
  const encoded = txs.map((tx) =>
    encodePacked(
      ['uint8', 'address', 'uint256', 'uint256', 'bytes'],
      [tx.operation, tx.to, tx.value, BigInt(size(tx.data)), tx.data],
    ),
  );

  return concat(encoded);
}

// ---------------------------------------------------------------------------
// 5. buildMultiSendSafeTx
// ---------------------------------------------------------------------------

/**
 * Wraps multiple calls in a single MultiSend DELEGATECALL SafeTxParams.
 * The returned object can be passed directly to `buildSafeTxTypedData`.
 */
export function buildMultiSendSafeTx(txs: SafeTxParams[]): SafeTxParams {
  const packed = encodeMultiSend(txs);

  const multiSendCalldata = encodeFunctionData({
    abi: MultiSendABI,
    functionName: 'multiSend',
    args: [packed],
  });

  return {
    to: SAFE_MULTISEND,
    value: 0n,
    data: multiSendCalldata,
    operation: 1, // DELEGATECALL
  };
}

// ---------------------------------------------------------------------------
// 6. getSafeNonce
// ---------------------------------------------------------------------------

/**
 * Reads the current nonce from a deployed Safe contract.
 */
export async function getSafeNonce(client: PublicClient, safeAddress: Address): Promise<bigint> {
  const nonce = await client.readContract({
    address: safeAddress,
    abi: SafeABI,
    functionName: 'nonce',
    args: [],
  });

  return nonce as bigint;
}

// ---------------------------------------------------------------------------
// 7. buildSafeSetupCalldata
// ---------------------------------------------------------------------------

/**
 * Encodes the `Safe.setup()` initializer calldata used when deploying a new
 * Safe proxy via `SafeProxyFactory.createProxyWithNonce`.
 *
 * For a minimal 1-of-1 Safe:
 *   - owners      = [owner]
 *   - threshold   = 1
 *   - to          = address(0)   (no delegate-call on setup)
 *   - data        = 0x           (no setup delegate-call data)
 *   - paymentToken = address(0)
 *   - payment      = 0
 *   - paymentReceiver = address(0)
 *
 * @param owner           The single owner of the Safe.
 * @param fallbackHandler The fallback handler address (defaults to SAFE_FALLBACK_HANDLER).
 */
export function buildSafeSetupCalldata(
  owner: Address,
  fallbackHandler: Address = SAFE_FALLBACK_HANDLER,
): Hex {
  return encodeFunctionData({
    abi: SafeABI,
    functionName: 'setup',
    args: [
      [owner],
      1n, // threshold
      '0x0000000000000000000000000000000000000000', // to
      '0x', // data
      fallbackHandler,
      '0x0000000000000000000000000000000000000000', // paymentToken
      0n, // payment
      '0x0000000000000000000000000000000000000000', // paymentReceiver
    ],
  });
}
