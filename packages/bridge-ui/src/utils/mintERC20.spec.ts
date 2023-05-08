import { Contract, ethers, type Signer } from 'ethers';
import { mintERC20 } from './mintERC20';
import type { Token } from '../domain/token';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { FREE_MINT_ERC20_ABI } from '../constants/abi';
import { selectChain } from './selectChain';
import { chains } from '../chain/chains';

jest.mock('../constants/envVars');

jest.mock('./selectChain', () => ({
  selectChain: jest.fn(),
}));

jest.mock('ethers', () => {
  const MockContract = jest.fn();
  MockContract.prototype.mint = jest.fn();

  return { Contract: MockContract };
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

const mockSigner = {
  getAddress: jest.fn().mockResolvedValue('0x123'),
} as unknown as Signer;

const mockTx = {} as ethers.Transaction;

describe('mintERC20', () => {
  beforeAll(() => {
    jest.mocked(Contract.prototype.mint).mockResolvedValue(mockTx);
  });

  beforeEach(() => {
    jest.mocked(selectChain).mockClear();
    jest.mocked(Contract).mockClear();
    jest.mocked(Contract.prototype.mint).mockClear();
  });

  it('should mint ERC20', async () => {
    const tx = await mintERC20(L1_CHAIN_ID, mockToken, mockSigner);

    // There was no switch of chain since token is on L1
    expect(selectChain).not.toHaveBeenCalled();

    expect(Contract).toHaveBeenCalledWith(
      '0x00',
      FREE_MINT_ERC20_ABI,
      mockSigner,
    );

    expect(Contract.prototype.mint).toHaveBeenCalledWith('0x123'); // from signer.getAddress()
    expect(tx).toBe(mockTx);
  });

  it('should switch network before minting ERC20', async () => {
    const tx = await mintERC20(L2_CHAIN_ID, mockToken, mockSigner);

    expect(selectChain).toHaveBeenCalledWith(chains[L1_CHAIN_ID]);

    expect(Contract).toHaveBeenCalledWith(
      '0x00',
      FREE_MINT_ERC20_ABI,
      mockSigner,
    );

    expect(Contract.prototype.mint).toHaveBeenCalledWith('0x123');
    expect(tx).toBe(mockTx);
  });
});
