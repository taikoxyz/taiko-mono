import { numberToHex, zeroHash } from 'viem';

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
import type { TokenType } from '$libs/token';

import { ALICE } from './addresses';
import { BLOCK_NUMBER_1 } from './blocks';
import { L1_CHAIN_ID, L2_CHAIN_ID } from './chains';
import { MOCK_MESSAGE_L1_L2 } from './messages';

export const MOCK_BRIDGE_TX_1 = {
  hash: zeroHash,
  status: 0,
  msgStatus: MessageStatus.NEW,
  msgHash: zeroHash,
  from: ALICE,
  amount: 123n,
  symbol: 'WAGMI',
  decimals: 18,
  srcChainId: BigInt(L1_CHAIN_ID),
  destChainId: BigInt(L2_CHAIN_ID),
  tokenType: 'ERC20' as TokenType,
  blockNumber: numberToHex(BLOCK_NUMBER_1),
  message: MOCK_MESSAGE_L1_L2,
} satisfies BridgeTransaction;
