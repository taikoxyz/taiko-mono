export const L1_RPC = 'https://l1rpc.internal.taiko.xyz';

export const L1_TOKEN_VAULT_ADDRESS =
  '0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f';

export const L1_BRIDGE_ADDRESS = '0x59b670e9fA9D0A427751Af201D676719a970857b';

export const L1_CROSS_CHAIN_SYNC_ADDRESS =
  '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE';

export const L1_SIGNAL_SERVICE_ADDRESS =
  '0x09635F643e140090A9A8Dcd712eD6285858ceBef';

export const L1_CHAIN_ID = 31336;

export const L1_CHAIN_NAME = 'Ethereum A3';

export const L1_EXPLORER_URL = 'https://l1explorer.internal.taiko.xyz';

export const L2_RPC = 'https://l2rpc.internal.taiko.xyz';

export const L2_TOKEN_VAULT_ADDRESS =
  '0x0000777700000000000000000000000000000002';

export const L2_BRIDGE_ADDRESS =
  import.meta.env?.VITE_L2_BRIDGE_ADDRESS ??
  '0x0000777700000000000000000000000000000004';

export const L2_CROSS_CHAIN_SYNC_ADDRESS =
  '0x0000777700000000000000000000000000000001';

export const L2_SIGNAL_SERVICE_ADDRESS =
  '0x0000777700000000000000000000000000000007';

export const L2_CHAIN_ID = 167001;

export const L2_CHAIN_NAME = 'Taiko A3';

export const L2_EXPLORER_URL = 'https://l2explorer.internal.taiko.xyz';

export const RELAYER_URL = 'https://relayer.internal.taiko.xyz/';

export const TEST_ERC20 = [
  {
    address: '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1',
    symbol: 'BLL',
    name: 'Bull Token',
  },
  {
    address: '0x0B306BF915C4d645ff596e518fAf3F9669b97016',
    symbol: 'HORSE',
    name: 'Horse Token',
  },
];
