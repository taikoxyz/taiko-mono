import { Contract, ethers, type Signer } from 'ethers';

import { freeMintErc20ABI } from '../constants/abi';
import { L1_CHAIN_ID } from '../constants/envVars';
import type { Token } from '../domain/token';
import { mintERC20 } from './mintERC20';

jest.mock('../constants/envVars');

jest.mock('ethers', () => {
  const MockContract = jest.fn();
  MockContract.prototype.mint = jest.fn();

  return { Contract: MockContract };
});

const mockToken = {
  name: 'MockToken',
  addresses: {
    [L1_CHAIN_ID]: '0x00',
  },
  decimals: 18,
  symbol: 'MKT',
} as unknown as Token;

const mockSigner = {
  getAddress: jest.fn().mockResolvedValue('0x123'),
} as unknown as Signer;

const mockTx = {} as ethers.Transaction;

describe('mintERC20', () => {
  beforeEach(() => {
    jest.mocked(Contract).mockClear();
    jest.mocked(Contract.prototype.mint).mockResolvedValue(mockTx);
  });

  it('should mint ERC20', async () => {
    const tx = await mintERC20(mockToken, mockSigner);

    expect(Contract).toHaveBeenCalledWith('0x00', freeMintErc20ABI, mockSigner);

    expect(Contract.prototype.mint).toHaveBeenCalledWith('0x123'); // from signer.getAddress()
    expect(tx).toBe(mockTx);
  });

  it('should switch network before minting ERC20', async () => {
    const tx = await mintERC20(mockToken, mockSigner);

    expect(Contract).toHaveBeenCalledWith('0x00', freeMintErc20ABI, mockSigner);

    expect(Contract.prototype.mint).toHaveBeenCalledWith('0x123');
    expect(tx).toBe(mockTx);
  });

  it('catches and rethrow the error if minting fails', async () => {
    jest
      .mocked(Contract.prototype.mint)
      .mockRejectedValue(new Error('test error'));

    await expect(mintERC20(mockToken, mockSigner)).rejects.toThrow(
      `found a problem minting ${mockToken.symbol}`,
    );
  });
});
