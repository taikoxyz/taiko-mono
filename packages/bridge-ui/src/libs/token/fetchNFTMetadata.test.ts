import axios from 'axios';
import { type Address, type Chain, zeroAddress } from 'viem';

import { destNetwork } from '$components/Bridge/state';
import { FetchMetadataError } from '$libs/error';
import { L1_CHAIN_ID, L2_CHAIN_ID, MOCK_ERC721, MOCK_ERC721_BASE64, MOCK_METADATA, MOCK_METADATA_BASE64 } from '$mocks';
import { getMetadataFromCache, isMetadataCached } from '$stores/metadata';
import { connectedSourceChain } from '$stores/network';
import type { TokenInfo } from '$stores/tokenInfo';

import { fetchNFTMetadata } from './fetchNFTMetadata';
import { getTokenAddresses } from './getTokenAddresses';
import { getTokenWithInfoFromAddress } from './getTokenWithInfoFromAddress';

vi.mock('../../generated/customTokenConfig', () => {
  const mockERC20 = {
    name: 'MockERC20',
    addresses: { '1': zeroAddress },
    symbol: 'MTF',
    decimals: 18,
    type: 'ERC20',
  };
  return {
    customToken: [mockERC20],
  };
});

vi.mock('./getTokenAddresses');

describe('fetchNFTMetadata()', () => {
  it('should return null if srcChainId or destChainId is not defined', async () => {
    const result = await fetchNFTMetadata(MOCK_ERC721);
    expect(result).toBe(null);
  });

  it('should return null if tokenInfo or tokenInfo.canonical.address is not defined', async () => {
    // Given
    connectedSourceChain.set({ id: L1_CHAIN_ID } as Chain);
    destNetwork.set({ id: L2_CHAIN_ID } as Chain);

    vi.mock('$stores/metadata', () => ({
      isMetadataCached: vi.fn(),
      getMetadataFromCache: vi.fn(),
      metadataCache: {
        update: vi.fn(),
      },
    }));

    const mockTokenInfo = {
      canonical: null,
      bridged: {
        chainId: L2_CHAIN_ID,
        address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
      },
    } satisfies TokenInfo;

    vi.mocked(isMetadataCached).mockReturnValue(true);
    vi.mocked(getMetadataFromCache).mockReturnValue(MOCK_METADATA);

    vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo);
    // When
    const result = await fetchNFTMetadata(MOCK_ERC721);

    // Then
    expect(result).toBe(null);
  });

  describe('when metadata is cached', () => {
    beforeAll(() => {
      connectedSourceChain.set({ id: L1_CHAIN_ID } as Chain);
      destNetwork.set({ id: L2_CHAIN_ID } as Chain);

      vi.mock('$stores/metadata', () => ({
        isMetadataCached: vi.fn(),
        getMetadataFromCache: vi.fn(),
        metadataCache: {
          update: vi.fn(),
        },
      }));
    });

    afterAll(() => {
      vi.restoreAllMocks();
      vi.resetAllMocks();
      vi.resetModules();
    });

    it('should return metadata if metadata is cached', async () => {
      // Given
      const mockTokenInfo = {
        canonical: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
        },
        bridged: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC721.addresses[L2_CHAIN_ID] as Address,
        },
      } satisfies TokenInfo;

      vi.mocked(isMetadataCached).mockReturnValue(true);
      vi.mocked(getMetadataFromCache).mockReturnValue(MOCK_METADATA);
      vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo);

      // When
      const result = await fetchNFTMetadata(MOCK_ERC721);

      // Then
      expect(result).toBe(MOCK_METADATA);
    });
  });

  describe('when metadata is not cached', () => {
    beforeAll(() => {
      vi.mock('$stores/metadata', () => ({
        isMetadataCached: vi.fn(),
        getMetadataFromCache: vi.fn(),
        metadataCache: {
          update: vi.fn(),
        },
      }));
      connectedSourceChain.set({ id: L1_CHAIN_ID } as Chain);
      destNetwork.set({ id: L2_CHAIN_ID } as Chain);
    });

    afterAll(() => {
      vi.restoreAllMocks();
      vi.resetAllMocks();
      vi.resetModules();
    });

    it('should return metadata if uri contains data:application/json;base64', async () => {
      // Given
      vi.mock('axios');
      const MOCK_NFT = {
        ...MOCK_ERC721_BASE64,
      };

      const mockTokenInfo = {
        canonical: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
        },
        bridged: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC721.addresses[L2_CHAIN_ID] as Address,
        },
      } satisfies TokenInfo;

      vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo);
      vi.mocked(isMetadataCached).mockReturnValue(false);
      vi.mocked(axios.get).mockResolvedValue({ status: 200, data: MOCK_METADATA_BASE64 });

      // When
      const result = await fetchNFTMetadata(MOCK_NFT);

      // Then
      expect(result).toStrictEqual(MOCK_METADATA_BASE64);
    });

    it('should return metadata if uri contains ipfs:// and ipfs contains image', async () => {
      // Given
      vi.mock('axios');

      const MOCK_NFT = {
        ...MOCK_ERC721,
        uri: 'ipfs://someuri',
      };

      const mockTokenInfo = {
        canonical: {
          chainId: L1_CHAIN_ID,
          address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
        },
        bridged: {
          chainId: L2_CHAIN_ID,
          address: MOCK_ERC721.addresses[L2_CHAIN_ID] as Address,
        },
      } satisfies TokenInfo;

      vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo);
      vi.mocked(isMetadataCached).mockReturnValue(false);
      vi.mocked(axios.get).mockResolvedValue({ status: 200, data: MOCK_METADATA });

      // When
      const result = await fetchNFTMetadata(MOCK_NFT);

      // Then
      expect(result).toBe(MOCK_METADATA);
    });

    describe('when uri is not found', () => {
      describe('fetchCrossChainNFTMetadata', () => {
        beforeAll(() => {
          vi.mock('axios');

          vi.mock('./fetchNFTMetadata', async (importOriginal) => {
            const actual = await importOriginal<typeof import('./fetchNFTMetadata')>();
            return {
              ...actual,
              crossChainFetchNFTMetadata: vi.fn().mockResolvedValue(MOCK_METADATA),
            };
          });

          vi.mock('./getTokenWithInfoFromAddress');
        });

        afterEach(() => {
          vi.restoreAllMocks();
          vi.resetAllMocks();
          vi.resetModules();
        });

        it('should return metadata if canonical token has valid metadata ', async () => {
          // Given
          const MOCK_BRIDGED_NFT = {
            ...MOCK_ERC721,
            uri: '',
          };

          const MOCK_CANONICAL_NFT = {
            ...MOCK_ERC721,
            uri: 'ipfs://someUri',
          };

          const mockTokenInfo = {
            canonical: {
              chainId: L1_CHAIN_ID,
              address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
            },
            bridged: {
              chainId: L2_CHAIN_ID,
              address: MOCK_ERC721.addresses[L2_CHAIN_ID] as Address,
            },
          } satisfies TokenInfo;

          vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo).mockResolvedValue(mockTokenInfo);
          vi.mocked(isMetadataCached).mockReturnValue(false);

          vi.mocked(getTokenWithInfoFromAddress).mockResolvedValue(MOCK_CANONICAL_NFT);

          // When
          const result = await fetchNFTMetadata(MOCK_BRIDGED_NFT);

          // Then
          expect(result).toBe(MOCK_METADATA);
        });

        it('should throw FetchMetadataError if no uri is found crosschain either', async () => {
          // Given
          const MOCK_BRIDGED_NFT = {
            ...MOCK_ERC721,
            uri: '',
          };

          const MOCK_CANONICAL_NFT = {
            ...MOCK_ERC721,
            uri: '', // No uri on canonical either
          };

          const mockTokenInfo = {
            canonical: {
              chainId: L1_CHAIN_ID,
              address: MOCK_ERC721.addresses[L1_CHAIN_ID] as Address,
            },
            bridged: {
              chainId: L2_CHAIN_ID,
              address: MOCK_ERC721.addresses[L2_CHAIN_ID] as Address,
            },
          } satisfies TokenInfo;

          vi.mocked(getTokenAddresses).mockResolvedValue(mockTokenInfo).mockResolvedValue(mockTokenInfo);
          vi.mocked(isMetadataCached).mockReturnValue(false);

          vi.mocked(getTokenWithInfoFromAddress).mockResolvedValue(MOCK_CANONICAL_NFT);

          // Then
          await expect(fetchNFTMetadata(MOCK_BRIDGED_NFT)).rejects.toBeInstanceOf(FetchMetadataError);
        });
      });
    });
  });
});
