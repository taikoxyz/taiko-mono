import { type Signer, Contract, BigNumber } from 'ethers';
import { getIsMintedWithEstimation } from './getIsMintedWithEstimation';
import { L1_CHAIN_ID } from '../constants/envVars';
import type { Token } from '../domain/token';

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
  addresses: [
    {
      chainId: L1_CHAIN_ID,
      address: '0x00',
    },
  ],
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
  beforeAll(() => {
    jest.mocked(Contract.prototype.estimateGas.mint).mockResolvedValue(mockGas);
  });

  it('should return true if user has already claimed', async () => {
    jest.mocked(Contract.prototype.minters).mockResolvedValue(true);

    const [isMinted, estimatedGas] = await getIsMintedWithEstimation(
      mockSigner,
      mockToken,
    );

    expect(isMinted).toBeTruthy();
    expect(estimatedGas).toBeNull();
  });

  it('should return false if user has not claimed', async () => {
    jest.mocked(Contract.prototype.minters).mockResolvedValue(false);

    const [isMinted, estimatedGas] = await getIsMintedWithEstimation(
      mockSigner,
      mockToken,
    );

    expect(isMinted).toBeFalsy();
    expect(estimatedGas).toEqual(BigNumber.from(mockGas).mul(mockGasPrice));
  });
});
