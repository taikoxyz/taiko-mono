import type { Hash } from 'viem';

import type { Message } from '$libs/bridge';

import { ALICE, BOB } from './addresses';
import { L1_CHAIN_ID, L2_A_CHAIN_ID } from './chains';

export const MOCK_MESSAGE_HASH_1 = '0xbcaf7fa6b46ab7028eda24afa3601e25dd74541edda9a2fa19d48500bd62ca8f' satisfies Hash;
export const MOCK_MESSAGE_HASH_2 = '0x840db7a92590dab15e0a7ebbe65b9acd5cd97abef3e4892e9472ad33c70a33cf' satisfies Hash;

export const MOCK_MESSAGE_L1_L2 = {
  srcChainId: BigInt(L1_CHAIN_ID),
  destChainId: BigInt(L2_A_CHAIN_ID),
  from: ALICE,
  to: BOB,
  srcOwner: ALICE,
  destOwner: ALICE,
  value: 0n,
  data: '0x',
  fee: 0n,
  gasLimit: 0,
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
  fee: 0n,
  gasLimit: 0,
  id: 420n,
} satisfies Message;
