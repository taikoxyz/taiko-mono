import type { Address } from 'viem';

vi.mock('$bridgeConfig', () => ({
  routingContractsMap: {
    1: {
      2: {
        bridgeAddress: '0x0000000000000000000000000000000000000002',
        erc20VaultAddress: '0x0000000000000000000000000000000000000020',
        erc721VaultAddress: '0x0000000000000000000000000000000000000721',
        erc1155VaultAddress: '0x0000000000000000000000000000000000001155',
      },
    },
  },
}));

vi.mock('$libs/token/getTokenAddresses', () => ({
  getTokenAddresses: vi.fn().mockResolvedValue({ canonical: { address: '0xabc', chainId: 1 }, bridged: null }),
}));

import { selectedNFTs } from '$components/Bridge/state';
import { type NFT, TokenType } from '$libs/token';

import { getBridgeArgs } from './getBridgeArgs';
import type { ERC1155BridgeArgs } from './types';

const commonArgs = {
  to: '0x0000000000000000000000000000000000000009' as Address,
  srcChainId: 1,
  destChainId: 2,
  fee: 0n,
  wallet: {} as never,
  tokenObject: {} as never,
};

const nft = {
  type: TokenType.ERC1155,
  symbol: 'MULTI',
  name: 'Multi',
  tokenId: 7,
  addresses: { 1: '0x0000000000000000000000000000000000000abc' },
} as unknown as NFT;

describe('getBridgeArgs for ERC1155', () => {
  it('carries the quantity through as a bigint', async () => {
    const args = (await getBridgeArgs(nft, 5n, commonArgs, [nft])) as ERC1155BridgeArgs;

    expect(args.amounts).toEqual([5n]);
  });

  it('does not round a quantity past the safe integer range', async () => {
    // A uint256 quantity used to go through Number() on its way to the vault, so anything
    // past 2^53 was bridged as a different amount than the user asked for
    const huge = BigInt(Number.MAX_SAFE_INTEGER) + 1n;

    const args = (await getBridgeArgs(nft, huge, commonArgs, [nft])) as ERC1155BridgeArgs;

    expect(args.amounts).toEqual([huge]);
  });

  it('sends a zero quantity for an ERC721, which the vault requires', async () => {
    const erc721 = { ...nft, type: TokenType.ERC721 } as unknown as NFT;

    const args = (await getBridgeArgs(erc721, 1n, commonArgs, [erc721])) as ERC1155BridgeArgs;

    expect(args.amounts).toEqual([0n]);
  });

  it('describes the NFTs it is given, not whatever the selection holds by now', async () => {
    // The caller captured its selection before its first await; a selection change since
    // then must not reach the transaction through a second read of the store
    const other = {
      ...nft,
      tokenId: 99,
      addresses: { 1: '0x0000000000000000000000000000000000000def' },
    } as unknown as NFT;
    selectedNFTs.set([other]);

    const args = (await getBridgeArgs(nft, 5n, commonArgs, [nft])) as ERC1155BridgeArgs;

    expect(args.token).toBe(nft.addresses[1]);
    expect(args.tokenIds).toEqual([7]);
  });

  it('refuses to build a transfer without any NFT', async () => {
    await expect(getBridgeArgs(nft, 5n, commonArgs, [])).rejects.toThrow(/No NFT/);
  });
});
