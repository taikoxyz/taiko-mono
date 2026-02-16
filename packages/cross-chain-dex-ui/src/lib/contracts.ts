export const UserOpsSubmitterFactoryABI = [
  {
    type: 'function',
    name: 'createSubmitter',
    inputs: [{ name: '_owner', type: 'address' }],
    outputs: [{ name: 'submitter_', type: 'address' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getSubmitter',
    inputs: [{ name: '_owner', type: 'address' }],
    outputs: [{ name: 'submitter_', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'submitters',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ name: 'submitter', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'SubmitterCreated',
    inputs: [
      { name: 'submitter', type: 'address', indexed: true },
      { name: 'owner', type: 'address', indexed: true },
      { name: 'deployer', type: 'address', indexed: true },
    ],
  },
] as const;

export const UserOpsSubmitterABI = [
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getDigest',
    inputs: [
      {
        name: '_ops',
        type: 'tuple[]',
        components: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    outputs: [{ name: 'digest_', type: 'bytes32' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'executeBatch',
    inputs: [
      {
        name: '_ops',
        type: 'tuple[]',
        components: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
      { name: '_signature', type: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const;

export const CrossChainSwapVaultL1ABI = [
  {
    type: 'function',
    name: 'swapETHForToken',
    inputs: [
      { name: '_minTokenOut', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'swapTokenForETH',
    inputs: [
      { name: '_tokenAmount', type: 'uint256' },
      { name: '_minETHOut', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'bridgeTokenToL2',
    inputs: [
      { name: '_amount', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'addLiquidityToL2',
    inputs: [
      { name: '_tokenAmount', type: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'swapToken',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
] as const;

export const SimpleDEXABI = [
  {
    type: 'function',
    name: 'getReserves',
    inputs: [],
    outputs: [
      { name: 'ethReserve_', type: 'uint256' },
      { name: 'tokenReserve_', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getAmountOut',
    inputs: [
      { name: '_amountIn', type: 'uint256' },
      { name: '_reserveIn', type: 'uint256' },
      { name: '_reserveOut', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut_', type: 'uint256' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'reserveETH',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'reserveToken',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
] as const;

export const BridgeABI = [
  {
    type: 'function',
    name: 'sendMessage',
    inputs: [
      {
        name: '_message',
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint64' },
          { name: 'fee', type: 'uint64' },
          { name: 'gasLimit', type: 'uint32' },
          { name: 'from', type: 'address' },
          { name: 'srcChainId', type: 'uint64' },
          { name: 'srcOwner', type: 'address' },
          { name: 'destChainId', type: 'uint64' },
          { name: 'destOwner', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    outputs: [
      { name: 'msgHash_', type: 'bytes32' },
      {
        name: 'message_',
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint64' },
          { name: 'fee', type: 'uint64' },
          { name: 'gasLimit', type: 'uint32' },
          { name: 'from', type: 'address' },
          { name: 'srcChainId', type: 'uint64' },
          { name: 'srcOwner', type: 'address' },
          { name: 'destChainId', type: 'uint64' },
          { name: 'destOwner', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    stateMutability: 'payable',
  },
] as const;

export const ERC20ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'approve',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'allowance',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'transfer',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
] as const;
