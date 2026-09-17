/**
 * The errors Permit2 raises on the signature itself, from Uniswap's `SignatureVerification`.
 * A `sendTokenWithPermit2` revert carries Permit2's error data unchanged through the vault,
 * so decoding against these alongside the vault ABI names the reason. Only the signature
 * errors are listed: they are the ones that say the flow cannot work for this signer, as
 * opposed to an expired deadline or a spent nonce, which a retry fixes.
 */
export const permit2SignatureErrorsAbi = [
  { type: 'error', name: 'InvalidSignatureLength', inputs: [] },
  { type: 'error', name: 'InvalidSignature', inputs: [] },
  { type: 'error', name: 'InvalidSigner', inputs: [] },
  { type: 'error', name: 'InvalidContractSignature', inputs: [] },
] as const;

/**
 * The ERC20 surface the permit flows read. `erc20Abi` in `$abi` is the bridged token's ABI
 * and predates EIP-2612, so the permit members are declared here.
 */
export const erc20PermitAbi = [
  {
    type: 'function',
    name: 'name',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
  },
  {
    type: 'function',
    name: 'allowance',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'nonces',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'DOMAIN_SEPARATOR',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'bytes32' }],
  },
  // ERC-5267, the token's own statement of its EIP-712 domain
  {
    type: 'function',
    name: 'eip712Domain',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'fields', type: 'bytes1' },
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
      { name: 'salt', type: 'bytes32' },
      { name: 'extensions', type: 'uint256[]' },
    ],
  },
] as const;
