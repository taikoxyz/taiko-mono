/**
 * The ABI of what a token vault sends across the bridge. Every vault's `sendToken` wraps an
 * `onMessageInvocation(bytes)` call around its own tuple, and the shape of that tuple is what
 * tells a reader which token, owner, recipient and amount a message carries.
 */
export const onMessageInvocationAbi = [
  {
    type: 'function',
    name: 'onMessageInvocation',
    inputs: [{ name: 'data', type: 'bytes' }],
    outputs: [],
    stateMutability: 'payable',
  },
] as const;

export const erc20InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'decimals', type: 'uint8' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256' },
] as const;

export const erc721InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256[]' },
] as const;

export const erc1155InvocationParameters = [
  {
    type: 'tuple',
    components: [
      { name: 'chainId', type: 'uint64' },
      { name: 'addr', type: 'address' },
      { name: 'symbol', type: 'string' },
      { name: 'name', type: 'string' },
    ],
  },
  { type: 'address' },
  { type: 'address' },
  { type: 'uint256[]' },
  { type: 'uint256[]' },
] as const;
