import {
  getContract,
  type GetContractResult,
  getPublicClient,
  getWalletClient,
  type PublicClient,
  type WalletClient,
} from '@wagmi/core';

import { freeMintErc20ABI } from '$abi';
import { mainnetChain } from '$libs/chain';

import { checkMintable } from './checkMintable';
import { testERC20Tokens } from './tokens';
import { MintableError } from './types';

vi.mock('$env/static/public');
vi.mock('@wagmi/core');
vi.mock('$abi');

const BLLToken = testERC20Tokens[0];

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

  it('should throw when wallet is not connected', async () => {
    vi.mocked(getWalletClient).mockResolvedValueOnce(null);

    try {
      await checkMintable(BLLToken, mainnetChain);
      expect.fail('should have thrown');
    } catch (error) {
      const { cause } = error as Error;
      expect(cause).toBe(MintableError.NOT_CONNECTED);
      expect(getWalletClient).toHaveBeenCalledWith({ chainId: mainnetChain.id });
    }
  });

  it('should throw when user has already minted', async () => {
    vi.mocked(mockTokenContract.read.minters).mockResolvedValueOnce(true);

    try {
      await checkMintable(BLLToken, mainnetChain);
      expect.fail('should have thrown');
    } catch (error) {
      const { cause } = error as Error;
      expect(cause).toBe(MintableError.TOKEN_MINTED);
      expect(getContract).toHaveBeenCalledWith({
        walletClient: mockWalletClient,
        abi: freeMintErc20ABI,
        address: BLLToken.addresses[mainnetChain.id],
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
      await checkMintable(BLLToken, mainnetChain);
      expect.fail('should have thrown');
    } catch (error) {
      const { cause } = error as Error;
      expect(cause).toBe(MintableError.INSUFFICIENT_BALANCE);
      expect(getPublicClient).toHaveBeenCalledWith({ chainId: mainnetChain.id });
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
      await checkMintable(BLLToken, mainnetChain);
    } catch (error) {
      expect.fail('should not have thrown');
    }
  });
});
