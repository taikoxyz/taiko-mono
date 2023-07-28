import type { Address, Hex } from 'viem';

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import { mergeUniqueTransactions } from '$libs/util/mergeTransactions';

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
      interval: null,
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
      interval: null,
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
      interval: null,
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
      interval: null,
    },
  ];

  it('should merge transactions without duplicates', () => {
    // When
    const result = mergeUniqueTransactions(localTxs, relayerTx);

    // Then
    expect(result).toEqual([...localTxs, ...relayerTx]);
  });

  it('should merge transactions and remove duplicates', () => {
    // Given
    const duplicateTx = relayerTx[1];
    const relayerTxWithDupes = [...relayerTx, duplicateTx];

    // When
    const result = mergeUniqueTransactions(localTxs, relayerTxWithDupes);

    // Then
    expect(result).toEqual([...localTxs, ...relayerTx]);
  });
});
