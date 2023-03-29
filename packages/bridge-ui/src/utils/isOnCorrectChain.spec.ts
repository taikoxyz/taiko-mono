import { ethers, Wallet } from 'ethers';
import { taikoChain } from '../chain/chains';
import { isOnCorrectChain } from './isOnCorrectChain';

jest.mock('../constants/envVars');

const mockProvider = {
  getCode: jest.fn(),
};

const mockSigner = {
  getChainId: jest.fn(),
  provider: mockProvider,
};

jest.mock('ethers', () => ({
  /* eslint-disable-next-line */
  ...(jest.requireActual('ethers') as object),
  Wallet: function () {
    return mockSigner;
  },
}));

describe('isOnCorrectChain()', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should return true when signer is on the correct chain', async () => {
    const signer = new Wallet('0x');

    mockSigner.getChainId.mockImplementationOnce(() => {
      return taikoChain.id;
    });

    mockProvider.getCode.mockImplementationOnce(() => {
      return '0x00';
    });
    const result = await isOnCorrectChain(signer, taikoChain.id);
    expect(result).toBe(true);
  });

  it('should return false when chainId is not correct', async () => {
    const signer = new Wallet('0x');

    mockSigner.getChainId.mockImplementationOnce(() => {
      return taikoChain.id + 1;
    });
    const result = await isOnCorrectChain(signer, taikoChain.id);
    expect(result).toBe(false);
  });

  it('should return false when bridgeAddress or tokenVaultAddress does not exist', async () => {
    const signer = new Wallet('0x');

    mockSigner.getChainId.mockImplementationOnce(() => {
      return taikoChain.id;
    });

    mockProvider.getCode.mockImplementationOnce(() => {
      return '0x00';
    });
    const result = await isOnCorrectChain(signer, 1);
    expect(result).toBe(false);
  });
});
