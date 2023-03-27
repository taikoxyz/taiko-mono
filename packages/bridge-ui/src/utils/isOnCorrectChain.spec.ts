import { ethers, Signer } from 'ethers';
import { mainnetChain, taikoChain } from '../chain/chains';
import { providers } from '../provider/providers';
import { isOnCorrectChain } from './isOnCorrectChain';

jest.mock('../constants/envVars');

describe('isOnCorrectChain()', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  const signer = ethers.Wallet.createRandom().connect(providers[taikoChain.id]);

  it('should return true when signer is on the correct chain', async () => {
    const result = await isOnCorrectChain(signer, taikoChain.id);
    expect(result).toBe(true);
  });

  it('should return false when bridgeAddress or tokenVaultAddress does not exist', async () => {
    const chainWithoutAddresses = 123;
    const result = await isOnCorrectChain(signer, chainWithoutAddresses);
    expect(result).toBe(false);
  });
});
