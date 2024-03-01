import type { Message } from '$libs/bridge';

import { ALICE, BOB } from './addresses';
import { L1_CHAIN_ID, L2_A_CHAIN_ID } from './chains';

export const MOCK_MESSAGE_L1_L2 = {
  srcChainId: BigInt(L1_CHAIN_ID),
  destChainId: BigInt(L2_A_CHAIN_ID),
  from: ALICE,
  to: BOB,
  srcOwner: ALICE,
  destOwner: ALICE,
  value: 0n,
  data: '0x',
  refundTo: ALICE,
  fee: 0n,
  gasLimit: 0n,
  memo: '',
  id: 420n,
} satisfies Message;

export const MOCK_MESSAGE_L2_L1 = {
  srcChainId: BigInt(L2_A_CHAIN_ID),
  destChainId: BigInt(L1_CHAIN_ID),
  from: ALICE,
  to: BOB,
  srcOwner: ALICE,
  destOwner: ALICE,
  value: 0n,
  data: '0x',
  refundTo: ALICE,
  fee: 0n,
  gasLimit: 0n,
  memo: '',
  id: 420n,
} satisfies Message;
