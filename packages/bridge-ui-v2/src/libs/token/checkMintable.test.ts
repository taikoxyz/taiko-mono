import {
  getContract,
  type GetContractResult,
  getPublicClient,
  getWalletClient,
  type PublicClient,
  type WalletClient,
} from '@wagmi/core';
import { zeroAddress } from 'viem';

import { freeMintErc20ABI } from '$abi';
import { InsufficientBalanceError, TokenMintedError } from '$libs/error';

import { checkMintable } from './checkMintable';
import { type Token, TokenType } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const PUBLIC_L1_CHAIN_ID = 11155111;
const PUBLIC_L2_CHAIN_ID = 1670005;

const L1_TOKEN_ADDRESS = '0x123456';

const BLLToken: Token = {
  name: 'MockToken',
  addresses: {
    [PUBLIC_L1_CHAIN_ID]: L1_TOKEN_ADDRESS,
    [PUBLIC_L2_CHAIN_ID]: zeroAddress,
  },
  symbol: 'MOCK',
  decimals: 18,
  type: TokenType.ERC20,
};

const mockWalletClient = {
  account: { address: '0x123' },
} as unknown as WalletClient;

const mockTokenContract = {
  read: {
    minters: vi.fn(),
  },
  estimateGas: {
    mint: vi.fn(),
  },
} as unknown as GetContractResult<readonly unknown[], unknown>;

const mockPublicClient = {
  getGasPrice: vi.fn(),
  getBalance: vi.fn(),
} as unknown as PublicClient;

describe('checkMintable', () => {
  beforeAll(() => {
    vi.mocked(getWalletClient).mockResolvedValue(mockWalletClient);
    vi.mocked(getContract).mockReturnValue(mockTokenContract);
    vi.mocked(getPublicClient).mockReturnValue(mockPublicClient);
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should throw when user has already minted', async () => {
    vi.mocked(mockTokenContract.read.minters).mockResolvedValueOnce(true);

    try {
      await checkMintable(BLLToken, 1);
      expect.fail('should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(TokenMintedError);
      expect(getContract).toHaveBeenCalledWith({
        walletClient: mockWalletClient,
        abi: freeMintErc20ABI,
        address: BLLToken.addresses[1],
      });
      expect(mockTokenContract.read.minters).toHaveBeenCalledWith([mockWalletClient.account.address]);
    }
  });

  it('should throw when user has insufficient balance', async () => {
    vi.mocked(mockTokenContract.read.minters).mockResolvedValueOnce(false);

    // Estimated gas to mint is 100
    vi.mocked(mockTokenContract.estimateGas.mint).mockResolvedValueOnce(BigInt(100));

    // Gas price is 2
    vi.mocked(mockPublicClient.getGasPrice).mockResolvedValueOnce(BigInt(2));

    // Estimated cost is 100 * 2 = 200

    // User balance is 100 (less than 200)
    vi.mocked(mockPublicClient.getBalance).mockResolvedValueOnce(BigInt(100));

    try {
      await checkMintable(BLLToken, 1);
      expect.fail('should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(InsufficientBalanceError);
      expect(getPublicClient).toHaveBeenCalled();
      expect(mockTokenContract.estimateGas.mint).toHaveBeenCalledWith([mockWalletClient.account.address]);
      expect(mockPublicClient.getBalance).toHaveBeenCalledWith({ address: mockWalletClient.account.address });
    }
  });

  it('should not throw', async () => {
    vi.mocked(mockTokenContract.read.minters).mockResolvedValueOnce(false);

    // Estimated gas to mint is 100
    vi.mocked(mockTokenContract.estimateGas.mint).mockResolvedValueOnce(BigInt(100));

    // Gas price is 2
    vi.mocked(mockPublicClient.getGasPrice).mockResolvedValueOnce(BigInt(2));

    // Estimated cost is 100 * 2 = 200

    // User balance is 300 (more than 200)
    vi.mocked(mockPublicClient.getBalance).mockResolvedValueOnce(BigInt(300));

    try {
      await checkMintable(BLLToken, 1);
    } catch (error) {
      expect.fail('should not have thrown');
    }
  });
});
