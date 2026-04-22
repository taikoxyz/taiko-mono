import { getBalance, type GetBalanceReturnType } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { fetchBalance } from './fetchBalance';
import { getAddress } from './getAddress';
import { ETHToken } from './tokens';
import { type Token, TokenType } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

vi.mock('$libs/wagmi/client');

// We don't want to test this function again, do we?
vi.mock('./getAddress');

const PUBLIC_L1_CHAIN_ID = 11155111;
const PUBLIC_L2_CHAIN_ID = 1670005;

const L1_TOKEN_ADDRESS = '0x123456';

const WALLET_ADDRESS = '0x1234567890';

const BLLToken: Token = {
  name: 'MockToken',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: L1_TOKEN_ADDRESS,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  symbol: 'MOCK',
  decimals: 18,
  type: TokenType.ERC20,
};

const mockBalanceForETH = {
  decimals: 18,
  formatted: '1',
  symbol: 'ETH',
  value: BigInt(1e18),
};

const mockBalanceForBLL = {
  decimals: BLLToken.decimals,
  formatted: '1',
  symbol: BLLToken.symbol,
  value: BigInt(1e18),
} satisfies GetBalanceReturnType;

const mockConfig = {
  chains: [],
};

describe('fetchBalance', () => {
  beforeEach(() => {
    vi.mocked(getAddress).mockReset();
    vi.mocked(getBalance).mockReset();
  });

  it('should return the balance of ETH', async () => {
    vi.mocked(getBalance).mockResolvedValueOnce(mockBalanceForETH);

    const balance = await fetchBalance({
      token: ETHToken,
      userAddress: WALLET_ADDRESS,
      srcChainId: Number(PUBLIC_L1_CHAIN_ID),
    });

    expect(balance).toEqual(mockBalanceForETH);
    expect(getAddress).not.toHaveBeenCalled();
    expect(getBalance).toHaveBeenCalledWith(mockConfig, {
      address: WALLET_ADDRESS,
      chainId: Number(PUBLIC_L1_CHAIN_ID),
    });
  });

  it('should return the balance of ERC20 token', async () => {
    vi.mocked(getAddress).mockResolvedValueOnce(BLLToken.addresses[PUBLIC_L1_CHAIN_ID]);
    vi.mocked(getBalance).mockResolvedValueOnce(mockBalanceForBLL);

    const balance = await fetchBalance({
      token: BLLToken,
      userAddress: WALLET_ADDRESS,
      srcChainId: Number(PUBLIC_L1_CHAIN_ID),
    });

    expect(balance).toEqual(mockBalanceForBLL);
    expect(getAddress).toHaveBeenCalledWith({
      token: BLLToken,
      srcChainId: Number(PUBLIC_L1_CHAIN_ID),
      destChainId: undefined,
    });
    expect(getBalance).toHaveBeenCalledWith(mockConfig, {
      address: WALLET_ADDRESS,
      chainId: Number(PUBLIC_L1_CHAIN_ID),
      token: BLLToken.addresses[PUBLIC_L1_CHAIN_ID],
    });
  });

  it('should return undefined if the token address is not found', async () => {
    vi.mocked(getAddress).mockResolvedValueOnce(zeroAddress);

    const balance = await fetchBalance({
      token: BLLToken,
      userAddress: WALLET_ADDRESS,
      srcChainId: Number(PUBLIC_L1_CHAIN_ID),
    });

    expect(balance).toBeUndefined();
    expect(getAddress).toHaveBeenCalledWith({
      token: BLLToken,
      srcChainId: Number(PUBLIC_L1_CHAIN_ID),
      destChainId: undefined,
    });
    expect(getBalance).not.toHaveBeenCalled();
  });

  it('should return undefined if ERC20 and no source chain is passed in', async () => {
    const balance = await fetchBalance({
      token: BLLToken,
      userAddress: WALLET_ADDRESS,
    });

    expect(balance).toBeUndefined();
  });
});
