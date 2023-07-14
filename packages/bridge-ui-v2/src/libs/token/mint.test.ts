import { getContract, type GetContractResult, getWalletClient, type WalletClient } from '@wagmi/core';

import { mint } from './mint';
import type { Token } from './types';

vi.mock('@wagmi/core', () => {
  return {
    getWalletClient: vi.fn(),
    getContract: vi.fn(),
  };
});

const mockToken = {
  symbol: 'MKT',
  addresses: { 1: '0x123' },
} as unknown as Token;

const mockWalletClient = {
  account: { address: '0x123' },
  chain: { id: 1 },
} as unknown as WalletClient;

const mockTokenContract = {
  write: {
    mint: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], WalletClient>;

describe('mint', () => {
  it('should return a tx hash when minting', async () => {
    vi.mocked(getWalletClient).mockResolvedValue(mockWalletClient);
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
    vi.mocked(mockTokenContract.write.mint).mockResolvedValue('0x123');

    await expect(mint(mockToken, mockWalletClient)).resolves.toEqual('0x123');
    expect(mockTokenContract.write.mint).toHaveBeenCalledWith([mockWalletClient.account.address]);
  });
});
