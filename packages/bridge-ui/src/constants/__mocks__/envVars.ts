export const L1_RPC = 'https://l1rpc.internal.taiko.xyz';

export const L1_TOKEN_VAULT_ADDRESS =
  '0xAE4C9bD0f7AE5398Df05043079596E2BF0079CE9';

export const L1_BRIDGE_ADDRESS = '0xAE4C9bD0f7AE5398Df05043079596E2BF0079CE9';

export const L1_HEADER_SYNC_ADDRESS =
  '0x9b557777Be33A8A2fE6aF93E017A0d139B439E5D';

export const L1_SIGNAL_SERVICE_ADDRESS =
  '0x162A36c9821eadeCFF9669A3940b7f72d055Cd1c';

export const L1_CHAIN_ID = 31336;

export const L1_CHAIN_NAME = 'Ethereum A2';

export const L1_EXPLORER_URL = 'https://l1explorer.internal.taiko.xyz';

export const L2_RPC = 'https://l2rpc.internal.taiko.xyz';

export const L2_TOKEN_VAULT_ADDRESS =
  '0x0000777700000000000000000000000000000002';

export const L2_BRIDGE_ADDRESS =
  import.meta.env?.VITE_TAIKO_BRIDGE_ADDRESS ??
  '0x0000777700000000000000000000000000000004';

export const L2_HEADER_SYNC_ADDRESS =
  '0x0000777700000000000000000000000000000001';

export const L2_SIGNAL_SERVICE_ADDRESS =
  '0x0000777700000000000000000000000000000007';

export const L2_CHAIN_ID = 167001;

export const L2_CHAIN_NAME = 'Taiko A2';

export const L2_EXPLORER_URL = 'https://l2explorer.internal.taiko.xyz';

export const RELAYER_URL = 'https://relayer.internal.taiko.xyz/';

export const TEST_ERC20 = [
  {
    address: '0x5B9fEDd37f0B92E7E282B19cEbCF06F57B77C604',
    symbol: 'BLL',
    name: 'Bull Token',
  },
  {
    address: '0xAED64948E0d09f4eb07d8B76A65Cd3d517c6Fb15',
    symbol: 'HORSE',
    name: 'Horse Token',
  },
];
