import { getPublicClient } from '@wagmi/core';
import { parseGwei } from 'viem';

import { gasLimitConfig } from '$config';
import { ETHToken } from '$libs/token';
import { getTokenAddresses } from '$libs/token/getTokenAddresses';
import { L1_CHAIN_ID, L2_CHAIN_ID, MOCK_ERC20, MOCK_ERC721, MOCK_ERC1155 } from '$mocks';

import { recommendProcessingFee } from './recommendProcessingFee';

vi.mock('@wagmi/core');
vi.mock('$customToken');
vi.mock('$bridgeConfig');
vi.mock('$libs/token/getTokenAddresses');

const mockClient = {
  request: vi.fn(),
  getBlock: vi.fn(),
  estimateMaxPriorityFeePerGas: vi.fn(),
  getGasPrice: vi.fn(),
};

describe('recommendedProcessingFee', () => {
  beforeAll(() => {
    vi.mocked(getPublicClient).mockReturnValue(mockClient);
    vi.mocked(mockClient.getBlock).mockReturnValue({ baseFeePerGas: 11n });
    vi.mocked(mockClient.estimateMaxPriorityFeePerGas).mockReturnValue(42n);
  });

  describe('ETH fees', () => {
    it('should calculate the recommended processing fee for ETH when gasPrice is a normal value (0.15 gwei)', async () => {
      // Given
      const token = ETHToken;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = gasLimitConfig.GAS_RESERVE;

      const reportedGasPrice = parseGwei('0.15');
      const feeMultiplicator = 1;

      const expectedFee = gasLimit * Number(reportedGasPrice) * feeMultiplicator;

      vi.mocked(mockClient.getGasPrice).mockReturnValue(reportedGasPrice);

      // When
      const result = await recommendProcessingFee({ token, destChainId, srcChainId });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe('ERC20 fees', () => {
    it('should calculate the recommended processing fee for deployed ERC20', async () => {
      // Given
      const token = MOCK_ERC20;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = gasLimitConfig.GAS_RESERVE + gasLimitConfig.erc20DeployedGasLimit;

      const reportedGasPrice = parseGwei('0.15');
      const feeMultiplicator = 1;

      const expectedFee = gasLimit * Number(reportedGasPrice) * feeMultiplicator;

      vi.mocked(mockClient.getGasPrice).mockReturnValue(reportedGasPrice);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC20.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC20.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({ token, destChainId, srcChainId });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe('ERC721 fees', () => {
    it('should calculate the recommended processing fee for deployed ERC721', async () => {
      // Given
      const token = MOCK_ERC721;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = gasLimitConfig.GAS_RESERVE + gasLimitConfig.erc721DeployedGasLimit;

      const reportedGasPrice = parseGwei('0.12');
      const feeMultiplicator = 1;

      const expectedFee = gasLimit * Number(reportedGasPrice) * feeMultiplicator;

      vi.mocked(mockClient.getGasPrice).mockReturnValue(reportedGasPrice);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC721.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC721.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({ token, destChainId, srcChainId });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });

  describe('ERC1155 fees', () => {
    it('should calculate the recommended processing fee for deployed ERC1155', async () => {
      // Given
      const token = MOCK_ERC1155;
      const srcChainId = L1_CHAIN_ID;
      const destChainId = L2_CHAIN_ID;

      const gasLimit = gasLimitConfig.GAS_RESERVE + gasLimitConfig.erc1155DeployedGasLimit;

      const reportedGasPrice = parseGwei('0.12');
      const feeMultiplicator = 1;

      const expectedFee = gasLimit * Number(reportedGasPrice) * feeMultiplicator;

      vi.mocked(mockClient.getGasPrice).mockReturnValue(reportedGasPrice);
      vi.mocked(getTokenAddresses).mockResolvedValue({
        bridged: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC1155.addresses[L1_CHAIN_ID],
        },
        canonical: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC1155.addresses[L2_CHAIN_ID],
        },
      });

      // When
      const result = await recommendProcessingFee({ token, destChainId, srcChainId });

      // Then
      expect(result).toBe(BigInt(expectedFee));
    });
  });
});
