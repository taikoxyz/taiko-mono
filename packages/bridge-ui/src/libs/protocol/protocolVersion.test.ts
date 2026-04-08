import { getPublicClient, readContract } from '@wagmi/core';
import type { Address } from 'viem';

import { routingContractsMap } from '$bridgeConfig';
import type { AddressConfig } from '$libs/bridge';

import { getProtocolVersion, ProtocolVersion } from './protocolVersion';

vi.mock('@wagmi/core');
vi.mock('$libs/wagmi', () => ({ config: {} }));

describe('getProtocolVersion', () => {
  const ethereumMainnetChainId = 1;
  const taikoMainnetChainId = 167000;
  const unknownSrcChainId = 32382;
  const unknownDestChainId = 167001;
  const ethereumHoodiChainId = 560048;
  const taikoHoodiChainId = 167013;
  const unknownRoute = routingContractsMap[unknownDestChainId][unknownSrcChainId];

  function createRoute(signalServiceAddress: Address): AddressConfig {
    return {
      bridgeAddress: '0x0000000000000000000000000000000000000001',
      erc20VaultAddress: '0x0000000000000000000000000000000000000002',
      erc721VaultAddress: '0x0000000000000000000000000000000000000003',
      erc1155VaultAddress: '0x0000000000000000000000000000000000000004',
      signalServiceAddress,
      anchorForkRouter: '0x0000000000000000000000000000000000000005',
    };
  }

  afterEach(() => {
    delete routingContractsMap[ethereumMainnetChainId]?.[taikoMainnetChainId];
    delete routingContractsMap[taikoHoodiChainId]?.[ethereumHoodiChainId];
    vi.clearAllMocks();
  });

  it('returns shasta immediately for mainnet routes', async () => {
    routingContractsMap[ethereumMainnetChainId] = {
      ...(routingContractsMap[ethereumMainnetChainId] ?? {}),
      [taikoMainnetChainId]: createRoute('0x0000000000000000000000000000000000000006'),
    };

    await expect(getProtocolVersion(taikoMainnetChainId, ethereumMainnetChainId)).resolves.toBe(ProtocolVersion.SHASTA);
    expect(readContract).not.toHaveBeenCalled();
    expect(getPublicClient).not.toHaveBeenCalled();
  });

  it('returns shasta immediately for hoodi routes', async () => {
    routingContractsMap[taikoHoodiChainId] = {
      ...(routingContractsMap[taikoHoodiChainId] ?? {}),
      [ethereumHoodiChainId]: createRoute('0x1670130000000000000000000000000000000005'),
    };

    await expect(getProtocolVersion(ethereumHoodiChainId, taikoHoodiChainId)).resolves.toBe(ProtocolVersion.SHASTA);
    expect(readContract).not.toHaveBeenCalled();
    expect(getPublicClient).not.toHaveBeenCalled();
  });

  it('falls back to the onchain shastaForkTimestamp when the route has no known timestamp', async () => {
    vi.mocked(readContract).mockResolvedValue(1_000n);
    vi.mocked(getPublicClient).mockReturnValue({
      getBlock: vi.fn().mockResolvedValue({ timestamp: 2_000n }),
    } as unknown as ReturnType<typeof getPublicClient>);

    await expect(getProtocolVersion(unknownSrcChainId, unknownDestChainId)).resolves.toBe(ProtocolVersion.SHASTA);
    expect(readContract).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        address: unknownRoute.signalServiceAddress,
        functionName: 'shastaForkTimestamp',
        chainId: unknownDestChainId,
      }),
    );
  });
});
