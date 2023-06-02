import { BigNumber, Contract, type Signer } from 'ethers';

import { L1_CHAIN_ID } from '../constants/envVars';
import type { Token } from '../domain/token';
import { getIsMintedWithEstimation } from './getIsMintedWithEstimation';

jest.mock('../constants/envVars');

jest.mock('ethers', () => {
  const actualEthers = jest.requireActual('ethers');

  const MockContract = jest.fn();
  MockContract.prototype = {
    minters: jest.fn(),
    estimateGas: {
      mint: jest.fn(),
    },
  };

  return {
    ...actualEthers,
    Contract: MockContract,
  };
});

const mockToken = {
  name: 'MockToken',
  addresses: {
    [L1_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'MKT',
} as unknown as Token;

const mockGas = BigNumber.from(2);
const mockGasPrice = BigNumber.from(3);

const mockSigner = {
  getAddress: jest.fn().mockResolvedValue('0x123'),
  getGasPrice: jest.fn().mockResolvedValue(mockGasPrice),
} as unknown as Signer;

describe('getIsMintedWithEstimation', () => {
  beforeEach(() => {
    jest.mocked(Contract.prototype.minters).mockResolvedValue(false);
    jest.mocked(Contract.prototype.estimateGas.mint).mockResolvedValue(mockGas);
  });

  it('should return true if user has already claimed', async () => {
    jest.mocked(Contract.prototype.minters).mockResolvedValue(true);
    const { isMinted, estimatedGas } = await getIsMintedWithEstimation(
      mockSigner,
      mockToken,
    );

    expect(isMinted).toBeTruthy();
    expect(estimatedGas).toBeNull();
  });

  it('should return false if user has not claimed', async () => {
    const { isMinted, estimatedGas } = await getIsMintedWithEstimation(
      mockSigner,
      mockToken,
    );

    expect(isMinted).toBeFalsy();
    expect(estimatedGas).toEqual(BigNumber.from(mockGas).mul(mockGasPrice));
  });

  it('catches and rethrow if getting minters fails', async () => {
    jest
      .mocked(Contract.prototype.minters)
      .mockRejectedValue(new Error('test error'));

    await expect(
      getIsMintedWithEstimation(mockSigner, mockToken),
    ).rejects.toThrow(
      `there was an issue getting minters for ${mockToken.symbol}`,
    );
  });

  it('catches and rethrow if estimating gas for minting fails', async () => {
    jest
      .mocked(Contract.prototype.estimateGas.mint)
      .mockRejectedValue(new Error('test error'));

    await expect(
      getIsMintedWithEstimation(mockSigner, mockToken),
    ).rejects.toThrow(
      `failed to estimate gas to mint token ${mockToken.symbol}`,
    );
  });
});
