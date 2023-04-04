import { chainCheck } from './chainCheck';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';
import { isOnCorrectChain } from './isOnCorrectChain';
import { chains } from '../chain/chains';
import type { Signer } from 'ethers';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';

jest.mock('@wagmi/core');
jest.mock('../constants/envVars');
jest.mock('./switchChainAndSetSigner');
jest.mock('./isOnCorrectChain');

const mockSigner = {} as Signer;

beforeAll(() => {
  jest.mocked(switchChainAndSetSigner).mockResolvedValue(undefined);
});

describe('chainCheck', () => {
  it('should switch chain and set signer', async () => {
    jest.mocked(isOnCorrectChain).mockResolvedValue(true);

    await chainCheck(L1_CHAIN_ID, L2_CHAIN_ID, mockSigner);

    expect(switchChainAndSetSigner).toHaveBeenCalledWith(chains[L2_CHAIN_ID]);
    expect(isOnCorrectChain).toHaveBeenCalledWith(mockSigner, L2_CHAIN_ID);
  });

  it('should not switch chain if already on correct chain', async () => {
    jest.mocked(isOnCorrectChain).mockResolvedValue(true);

    await chainCheck(L1_CHAIN_ID, L1_CHAIN_ID, mockSigner);

    expect(switchChainAndSetSigner).not.toHaveBeenCalled();
    expect(isOnCorrectChain).toHaveBeenCalledWith(mockSigner, L1_CHAIN_ID);
  });

  it('should throw error if not on correct chain', async () => {
    jest.mocked(isOnCorrectChain).mockResolvedValue(false);

    await expect(
      chainCheck(L1_CHAIN_ID, L2_CHAIN_ID, mockSigner),
    ).rejects.toThrowError();
  });
});
