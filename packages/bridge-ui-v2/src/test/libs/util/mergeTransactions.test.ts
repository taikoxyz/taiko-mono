import type { Address, Hex } from 'viem';

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { TokenType } from '$libs/token';
import { mergeAndCaptureOutdatedTransactions } from '$libs/util/mergeTransactions';

describe('mergeUniqueTransactions', () => {
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
      status: MessageStatus.DONE,
      msgHash: 'msg1' as Hex,
      receipt: undefined,
      tokenType: TokenType.ERC20,
    },
    {
      hash: 'hash2' as Hex,
      from: 'address2' as Address,
      amount: BigInt(2000),
      symbol: 'symbol2',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      status: MessageStatus.DONE,
      msgHash: 'msg2' as Hex,
      receipt: undefined,
      tokenType: TokenType.ERC20,
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
      status: MessageStatus.DONE,
      msgHash: 'msg3' as Hex,
      receipt: undefined,
      tokenType: TokenType.ERC20,
    },
    {
      hash: 'hash4' as Hex,
      from: 'address4' as Address,
      amount: BigInt(4000),
      symbol: 'symbol4',
      decimals: 2,
      srcChainId: BigInt(1),
      destChainId: BigInt(2),
      status: MessageStatus.DONE,
      msgHash: 'msg4' as Hex,
      receipt: undefined,
      tokenType: TokenType.ERC20,
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
        status: MessageStatus.DONE,
        msgHash: 'msg2' as Hex,
        receipt: undefined,
        tokenType: TokenType.ERC20,
      },
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
