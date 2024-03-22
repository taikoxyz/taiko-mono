import type { Address, Hex } from 'viem';

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import type { TokenType } from '$libs/token';
import { mergeAndCaptureOutdatedTransactions } from '$libs/util/mergeTransactions';

function setupMocks() {
  vi.mock('@wagmi/core');
  vi.mock('@web3modal/wagmi');
  vi.mock('$customToken', () => {
    return {
      customToken: [
        {
          name: 'Bull Token',
          addresses: {
            '31336': '0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0',
            '167002': '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE',
          },
          symbol: 'BLL',
          decimals: 18,
          type: 'ERC20',
          logoURI: 'ipfs://QmezMTpT6ovJ3szb3SKDM9GVGeQ1R8DfjYyXG12ppMe2BY',
          mintable: true,
        },
        {
          name: 'Horse Token',
          addresses: {
            '31336': '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
            '167002': '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1',
          },
          symbol: 'HORSE',
          decimals: 18,
          type: 'ERC20',
          logoURI: 'ipfs://QmU52ZxmSiGX24uDPNUGG3URyZr5aQdLpACCiD6tap4Mgc',
          mintable: true,
        },
      ],
    };
  });
}

describe('mergeUniqueTransactions', () => {
  beforeEach(() => {
    setupMocks();
  });

  // Given
  const localTxs: BridgeTransaction[] = [
    {
      hash: 'hash1' as Hex,
      from: 'address1' as Address,
      amount: BigInt(1000),
      symbol: 'symbol1',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      msgStatus: MessageStatus.DONE,
      msgHash: 'msg1' as Hex,
      receipt: undefined,
      blockNumber: '0x123',

      tokenType: 'ERC20' as TokenType,
    },
    {
      hash: 'hash2' as Hex,
      from: 'address2' as Address,
      amount: BigInt(2000),
      symbol: 'symbol2',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      msgStatus: MessageStatus.DONE,
      msgHash: 'msg2' as Hex,
      receipt: undefined,
      tokenType: 'ERC20' as TokenType,
      blockNumber: '0x123',
    },
  ];

  const relayerTx: BridgeTransaction[] = [
    {
      hash: 'hash3' as Hex,
      from: 'address3' as Address,
      amount: BigInt(3000),
      symbol: 'symbol3',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      msgStatus: MessageStatus.DONE,
      msgHash: 'msg3' as Hex,
      receipt: undefined,
      tokenType: 'ERC20' as TokenType,
      blockNumber: '0x123',
    },
    {
      hash: 'hash4' as Hex,
      from: 'address4' as Address,
      amount: BigInt(4000),
      symbol: 'symbol4',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      msgStatus: MessageStatus.DONE,
      msgHash: 'msg4' as Hex,
      receipt: undefined,
      tokenType: 'ERC20' as TokenType,
      blockNumber: '0x123',
    },
  ];

  it('should merge transactions when no outdated local ones', () => {
    // When
    const result = mergeAndCaptureOutdatedTransactions(localTxs, relayerTx);

    // Then
    expect(extractHashes(result.mergedTransactions)).toEqual(extractHashes([...localTxs, ...relayerTx]));
    expect(result.outdatedLocalTransactions).toEqual([]);
  });

  it('should identify and capture outdated local transactions', () => {
    // Given
    const outdatedTx = relayerTx[0];
    const localWithOutdated = [...localTxs, outdatedTx];

    // When
    const result = mergeAndCaptureOutdatedTransactions(localWithOutdated, relayerTx);

    // Then
    expect(extractHashes(result.mergedTransactions)).toEqual(extractHashes([...localTxs, ...relayerTx]));
    expect(result.outdatedLocalTransactions).toEqual([outdatedTx]);
  });

  it('should merge transactions and capture outdated ones, complex', () => {
    // Given

    const localWithOutdated = [
      ...localTxs,
      {
        hash: 'hash3' as Hex,
        from: 'address2' as Address,
        amount: BigInt(2000),
        symbol: 'symbol2',
        decimals: 2,
        srcChainId: BigInt(1),
        destChainId: BigInt(2),
        msgStatus: MessageStatus.DONE,
        msgHash: 'msg2' as Hex,
        receipt: undefined,
        blockNumber: '0x123',
        tokenType: 'ERC20' as TokenType,
      } satisfies BridgeTransaction,
    ];

    const expectedMergedHashes = extractHashes([...localTxs, ...relayerTx]);
    const expectedOutdatedHashes = ['hash3' as Hex];

    // When
    const result = mergeAndCaptureOutdatedTransactions(localWithOutdated, relayerTx);

    // Then
    expect(extractHashes(result.mergedTransactions)).toEqual(expectedMergedHashes);
    expect(extractHashes(result.outdatedLocalTransactions)).toEqual(expectedOutdatedHashes);
  });
});

function extractHashes(transactions: BridgeTransaction[]): Hex[] {
  return transactions.map((tx) => tx.hash);
}
