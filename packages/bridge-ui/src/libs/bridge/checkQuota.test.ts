import { readContract } from '@wagmi/core';
import { zeroAddress } from 'viem';

import { TokenType } from '$libs/token/types';

import { ALICE } from '../../tests/mocks/addresses';
import { MOCK_MESSAGE_L2_L1 } from '../../tests/mocks/messages';
import { isClaimBlockedByQuota } from './checkQuota';
import type { BridgeTransaction } from './types';

vi.mock('@wagmi/core');
vi.mock('$libs/wagmi', () => ({ config: {} }));
vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      21: {
        bridgeAddress: '0x1000010000000000000000000000000000000001',
        erc20VaultAddress: '0x1000010000000000000000000000000000000002',
        erc721VaultAddress: '0x1000010000000000000000000000000000000003',
        erc1155VaultAddress: '0x1000010000000000000000000000000000000004',
        signalServiceAddress: '0x1000010000000000000000000000000000000005',
        quotaManagerAddress: '0x1000010000000000000000000000000000000006',
      },
    },
    21: {
      1: {
        bridgeAddress: '0x2000010000000000000000000000000000000001',
        erc20VaultAddress: '0x2000010000000000000000000000000000000002',
        erc721VaultAddress: '0x2000010000000000000000000000000000000003',
        erc1155VaultAddress: '0x2000010000000000000000000000000000000004',
        signalServiceAddress: '0x2000010000000000000000000000000000000005',
      },
    },
  },
}));

const TOKEN = '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';

function bridgeTx(overrides: Partial<BridgeTransaction> = {}): BridgeTransaction {
  return {
    srcTxHash: zeroAddress,
    msgHash: zeroAddress,
    processingFee: 0n,
    from: ALICE,
    amount: 100n,
    symbol: 'USDC',
    srcChainId: 21n,
    destChainId: 1n,
    tokenType: TokenType.ERC20,
    canonicalTokenAddress: TOKEN,
    message: MOCK_MESSAGE_L2_L1,
    ...overrides,
  };
}

describe('isClaimBlockedByQuota', () => {
  beforeEach(() => {
    vi.mocked(readContract).mockReset();
  });

  it('returns true when the route quota manager reports less available quota than the claim amount', async () => {
    vi.mocked(readContract).mockResolvedValue(99n);

    await expect(isClaimBlockedByQuota(bridgeTx())).resolves.toBe(true);
    expect(readContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        address: '0x1000010000000000000000000000000000000006',
        chainId: 1,
        functionName: 'availableQuota',
        args: [TOKEN, 0n],
      }),
    );
  });

  it('returns false when quota is available', async () => {
    vi.mocked(readContract).mockResolvedValue(100n);

    await expect(isClaimBlockedByQuota(bridgeTx())).resolves.toBe(false);
  });

  it('returns false when the destination route has no quota manager configured', async () => {
    await expect(isClaimBlockedByQuota(bridgeTx({ srcChainId: 1n, destChainId: 21n }))).resolves.toBe(false);
    expect(readContract).not.toHaveBeenCalled();
  });

  it('returns false for NFTs because quota does not apply', async () => {
    await expect(isClaimBlockedByQuota(bridgeTx({ tokenType: TokenType.ERC721 }))).resolves.toBe(false);
    expect(readContract).not.toHaveBeenCalled();
  });
});
