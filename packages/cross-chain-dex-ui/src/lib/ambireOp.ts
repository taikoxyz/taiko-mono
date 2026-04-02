import {
  type Address,
  type Hex,
  type PublicClient,
  encodeAbiParameters,
  keccak256,
  concat,
  toHex,
  encodeFunctionData,
} from 'viem';
import { AmbireAccountABI } from './contracts';
import { UserOp } from '../types';

// EIP-7702 delegation designator prefix
const DELEGATION_PREFIX = '0xef0100' as const;

/**
 * AmbireAccount Transaction struct matching the on-chain struct.
 */
export interface AmbireTransaction {
  to: Address;
  value: bigint;
  data: Hex;
}

/**
 * Check if an address has an EIP-7702 delegation.
 * Returns the delegation target address if found, null otherwise.
 */
export async function detect7702Delegation(
  client: PublicClient,
  address: Address,
): Promise<Address | null> {
  try {
    const code = await client.getCode({ address });
    if (!code || code === '0x') return null;
    if (code.toLowerCase().startsWith(DELEGATION_PREFIX) && code.length === 48) {
      return `0x${code.slice(8)}` as Address;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Check if a delegation target is an AmbireAccount by looking for the
 * execute function selector in its bytecode.
 */
export async function isAmbireAccount(
  client: PublicClient,
  delegationTarget: Address,
): Promise<boolean> {
  try {
    const code = await client.getCode({ address: delegationTarget });
    if (!code || code === '0x') return false;
    // Selector for execute((address,uint256,bytes)[],bytes) = 0x6171d1c9
    return code.toLowerCase().includes('6171d1c9');
  } catch {
    return false;
  }
}

/**
 * Read the current nonce from an AmbireAccount.
 */
export async function getAmbireNonce(
  client: PublicClient,
  account: Address,
): Promise<bigint> {
  return (await client.readContract({
    address: account,
    abi: AmbireAccountABI,
    functionName: 'nonce',
  })) as bigint;
}

/**
 * Compute the execute hash that AmbireAccount.execute() computes on-chain:
 * keccak256(abi.encode(address(this), block.chainid, currentNonce, txns))
 */
export function computeExecuteHash(
  account: Address,
  chainId: number,
  nonce: bigint,
  txns: AmbireTransaction[],
): Hex {
  const txnTuples = txns.map((t) => ({
    to: t.to,
    value: t.value,
    data: t.data,
  }));

  return keccak256(
    encodeAbiParameters(
      [
        { type: 'address' },
        { type: 'uint256' },
        { type: 'uint256' },
        {
          type: 'tuple[]',
          components: [
            { name: 'to', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'data', type: 'bytes' },
          ],
        },
      ],
      [account, BigInt(chainId), nonce, txnTuples],
    ),
  );
}

/**
 * Append EthSign mode byte (0x01) to a signature for SignatureValidatorV2.
 */
export function appendEthSignMode(signature: Hex): Hex {
  return concat([signature, toHex(1, { size: 1 })]) as Hex;
}

/**
 * Append EIP-712 mode byte (0x00) to a signature for SignatureValidatorV2.
 */
export function appendEIP712Mode(signature: Hex): Hex {
  return concat([signature, toHex(0, { size: 1 })]) as Hex;
}

/**
 * AmbireAccount v2 EIP-712 signing with mode 0x00 (EIP712 direct).
 *
 * The deployed contract verifies signatures against the AmbireExecuteAccountOp
 * EIP-712 hash, which includes full typed transaction data:
 *   AmbireExecuteAccountOp(address account, uint256 chainId, uint256 nonce, Transaction[] calls, bytes32 hash)
 *   Transaction(address to, uint256 value, bytes data)
 *
 * The user signs this via signTypedData, and the contract does direct ecrecover
 * (mode 0x00) against the same EIP-712 hash it computes internally.
 */

const AMBIRE_DOMAIN = {
  name: 'Ambire' as const,
  version: '1' as const,
  salt: '0x0000000000000000000000000000000000000000000000000000000000000000' as Hex,
};

/**
 * Build the AmbireExecuteAccountOp EIP-712 typed data for signTypedData.
 *
 * The deployed AmbireAccount v2 contract verifies signatures against
 * the AmbireExecuteAccountOp EIP-712 hash (when using mode 0x00 = EIP712 direct).
 * This includes the full typed transaction data for readable signing prompts.
 */
export function buildAmbireExecuteTypedData(
  account: Address,
  chainId: number,
  nonce: bigint,
  txns: AmbireTransaction[],
  executeHash: Hex,
) {
  return {
    domain: {
      ...AMBIRE_DOMAIN,
      chainId,
      verifyingContract: account,
    },
    types: {
      AmbireExecuteAccountOp: [
        { name: 'account', type: 'address' },
        { name: 'chainId', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'calls', type: 'Transaction[]' },
        { name: 'hash', type: 'bytes32' },
      ],
      Transaction: [
        { name: 'to', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'data', type: 'bytes' },
      ],
    },
    primaryType: 'AmbireExecuteAccountOp' as const,
    message: {
      account,
      chainId: BigInt(chainId),
      nonce,
      calls: txns.map((t) => ({ to: t.to, value: t.value, data: t.data })),
      hash: executeHash,
    },
  };
}

/**
 * Convert UserOp[] to AmbireTransaction[].
 */
export function userOpsToAmbireTransactions(ops: UserOp[]): AmbireTransaction[] {
  return ops.map((op) => ({
    to: op.target,
    value: op.value,
    data: op.data,
  }));
}

/**
 * Encode the full AmbireAccount.execute(txns, signature) calldata.
 */
export function buildAmbireExecuteCalldata(
  txns: AmbireTransaction[],
  signature: Hex,
): Hex {
  return encodeFunctionData({
    abi: AmbireAccountABI,
    functionName: 'execute',
    args: [txns, signature],
  });
}
