export const bridgeAbi = [
  {
    type: 'event',
    name: 'MessageStatusChanged',
  },
] as const;

export const tokenVaultABI = [
  {
    type: 'event',
    name: 'ERC20Received',
  },
] as const;

export const crossChainSyncABI = [
  {
    type: 'event',
    name: 'CrossChainSynced',
  },
] as const;

export const freeMintErc20Abi = [
  {
    type: 'event',
    name: 'Approval',
  },
] as const;

export const erc20Abi = [
  {
    type: 'event',
    name: 'Transfer',
  },
] as const;
