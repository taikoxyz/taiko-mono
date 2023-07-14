import { fetchBalance, type WalletClient } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { PUBLIC_L1_CHAIN_ID } from '$env/static/public';

import { getAddress } from './getAddress';
import { getBalance } from './getBalance';
import { ETHToken, testERC20Tokens } from './tokens';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

// We don't want to test this function again, do we?
vi.mock('./getAddress');

const BLLToken = testERC20Tokens[0];

const mockWalletClient = {
  account: { address: '0xasdf' },
} as unknown as WalletClient;

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
};

describe('getBalance', () => {
  beforeEach(() => {
    vi.mocked(getAddress).mockReset();
    vi.mocked(fetchBalance).mockReset();
  });

  it('should return the balance of ETH', async () => {
    vi.mocked(fetchBalance).mockResolvedValueOnce(mockBalanceForETH);

    const balance = await getBalance(ETHToken, mockWalletClient.account.address);

    expect(balance).toEqual(mockBalanceForETH);
    expect(getAddress).not.toHaveBeenCalled();
    expect(fetchBalance).toHaveBeenCalledWith({ address: mockWalletClient.account.address });
  });

  it('should return the balance of ERC20 token', async () => {
    vi.mocked(getAddress).mockResolvedValueOnce(BLLToken.addresses[PUBLIC_L1_CHAIN_ID]);
    vi.mocked(fetchBalance).mockResolvedValueOnce(mockBalanceForBLL);

    const balance = await getBalance(BLLToken, mockWalletClient.account.address, +PUBLIC_L1_CHAIN_ID);

    expect(balance).toEqual(mockBalanceForBLL);
    expect(getAddress).toHaveBeenCalledWith(BLLToken, +PUBLIC_L1_CHAIN_ID, undefined);
    expect(fetchBalance).toHaveBeenCalledWith({
      address: mockWalletClient.account.address,
      chainId: +PUBLIC_L1_CHAIN_ID,
      token: BLLToken.addresses[PUBLIC_L1_CHAIN_ID],
    });
  });

  it('should return null if the token address is not found', async () => {
    vi.mocked(getAddress).mockResolvedValueOnce(zeroAddress);

    const balance = await getBalance(BLLToken, mockWalletClient.account.address, +PUBLIC_L1_CHAIN_ID);

    expect(balance).toBeNull();
    expect(getAddress).toHaveBeenCalledWith(BLLToken, +PUBLIC_L1_CHAIN_ID, undefined);
    expect(fetchBalance).not.toHaveBeenCalled();
  });
});
