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
  beforeAll(() => {
    vi.mocked(getWalletClient).mockResolvedValue(mockWalletClient);
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
  });

  it('should throw an error when minting', async () => {
    vi.mocked(mockTokenContract.write.mint).mockRejectedValue(new Error('BAM!!'));

    await expect(mint(mockToken, mockWalletClient)).rejects.toThrow(`found a problem minting ${mockToken.symbol}`);
  });

  it('should return a tx hash when minting', async () => {
    vi.mocked(mockTokenContract.write.mint).mockResolvedValue('0x123');

    await expect(mint(mockToken, mockWalletClient)).resolves.toEqual('0x123');
  });
});
