import { getPublicClient, readContract } from '@wagmi/core';
import { keccak256, toBytes, zeroAddress, zeroHash } from 'viem';

import { signalServiceAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { ClientError, ProofGenerationError } from '$libs/error';
import { BridgeProver } from '$libs/proof/BridgeProver';
import type { ClientWithEthGetProofRequest, EthGetProofResponse } from '$libs/proof/types';
import { config } from '$libs/wagmi';
import { BLOCK_NUMBER_1, L1_ADDRESSES, L1_CHAIN_ID, L2_CHAIN_ID, MOCK_BRIDGE_TX_1, STORAGE_KEY_1 } from '$mocks';

vi.mock('$bridgeConfig');

describe('BridgeProver', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe('getSignalSlot()', () => {
    it('should return signalslot', async () => {
      // Given
      const bridgeProver = new BridgeProver();
      const chainId = L1_CHAIN_ID;
      const contractAddress = L1_ADDRESSES.bridgeAddress;
      const msgHash = zeroHash;

      // When
      const result = await bridgeProver.getSignalSlot(chainId, contractAddress, msgHash);

      // Then
      expect(result).toBe('0xff44c639166e92e749d33ed59058223394b1e34751584ee25bc5a09f45ad4eba');
    });
  });

  describe('getBlockNumber()', () => {
    it(' should return block number', async () => {
      // Given
      const bridgeProver = new BridgeProver();
      const srcChainId = BigInt(L1_CHAIN_ID);
      const destChainId = BigInt(L2_CHAIN_ID);

      vi.mocked(readContract).mockResolvedValueOnce([BLOCK_NUMBER_1, 1234]);

      // When
      const result = await bridgeProver.getLatestSrcBlockNumber(srcChainId, destChainId);

      // Then
      expect(result).toBe(BLOCK_NUMBER_1);
      expect(readContract).toHaveBeenCalledWith(config, {
        address: routingContractsMap[L2_CHAIN_ID][L1_CHAIN_ID].signalServiceAddress,
        abi: signalServiceAbi,
        functionName: 'getSyncedChainData',
        args: [srcChainId, keccak256(toBytes('STATE_ROOT')), 0n],
        chainId: Number(destChainId),
      });
    });
  });

  describe('getProof()', () => {
    it('should return proof', async () => {
      // Given
      const bridgeProver = new BridgeProver();

      const expectedProof = {
        balance: '0x1234',
        storageProof: [
          {
            key: '0x1234',
            value: '0x1234',
            proof: ['0x1234', '0x1234', '0x1234'],
          },
        ],
        codeHash: zeroHash,
        nonce: 0,
        storageHash: zeroHash,
        accountProof: ['0x1234', '0x1234', '0x1234'],
      } satisfies EthGetProofResponse;

      const requestMock = vi.fn().mockResolvedValue(expectedProof);

      const mockClient = {
        request: requestMock,
      } as ClientWithEthGetProofRequest;

      vi.mocked(getPublicClient).mockReturnValue(mockClient);

      // When
      const result = await bridgeProver.getProof({
        bridgeTx: MOCK_BRIDGE_TX_1,
        blockNumber: BLOCK_NUMBER_1,
        key: STORAGE_KEY_1,
        signalServiceAddress: zeroAddress,
      });

      // Then
      expect(result).toBe(expectedProof);
    });

    it('should throw when storageProof value is 0', async () => {
      // Given
      const bridgeProver = new BridgeProver();

      const invalidProof = {
        balance: '0x1234',
        storageProof: [
          {
            key: '0x1234',
            value: '0x0',
            proof: ['0x1234', '0x1234', '0x1234'],
          },
        ],
        codeHash: zeroHash,
        nonce: 0,
        storageHash: zeroHash,
        accountProof: ['0x1234', '0x1234', '0x1234'],
      } satisfies EthGetProofResponse;

      const requestMock = vi.fn().mockResolvedValue(invalidProof);

      const mockClient = {
        request: requestMock,
      } as ClientWithEthGetProofRequest;

      vi.mocked(getPublicClient).mockReturnValue(mockClient);

      // Then
      await expect(
        bridgeProver.getProof({
          bridgeTx: MOCK_BRIDGE_TX_1,
          blockNumber: BLOCK_NUMBER_1,
          key: STORAGE_KEY_1,
          signalServiceAddress: zeroAddress,
        }),
      ).rejects.toBeInstanceOf(ProofGenerationError);
    });

    it('should fail when client cant be found', async () => {
      // Given
      const bridgeProver = new BridgeProver();

      vi.mocked(getPublicClient).mockImplementationOnce(() => {
        throw new Error('any error');
      });

      // When // Then
      await expect(
        bridgeProver.getProof({
          bridgeTx: MOCK_BRIDGE_TX_1,
          blockNumber: BLOCK_NUMBER_1,
          key: STORAGE_KEY_1,
          signalServiceAddress: zeroAddress,
        }),
      ).rejects.toBeInstanceOf(ClientError);

      expect(getPublicClient).toHaveBeenCalledWith(config, { chainId: L1_CHAIN_ID });
    });

    // should fail when no message is found
    it('should fail when no message is found', async () => {
      // Given
      const bridgeProver = new BridgeProver();

      const txWithoutMessage = { ...MOCK_BRIDGE_TX_1, message: undefined };

      // When // Then
      await expect(
        bridgeProver.getProof({
          bridgeTx: txWithoutMessage,
          blockNumber: BLOCK_NUMBER_1,
          key: STORAGE_KEY_1,
          signalServiceAddress: zeroAddress,
        }),
      ).rejects.toBeInstanceOf(ProofGenerationError);

      expect(getPublicClient).not.toHaveBeenCalled();
    });
  });
});
