import type { GetBalanceReturnType } from '@wagmi/core';
import { derived, writable } from 'svelte/store';
import type { Address, Chain } from 'viem';

import { bridges } from '$libs/bridge';
import { chains } from '$libs/chain';
import { ProcessingFeeMethod } from '$libs/fee';
import type { NFT, Token } from '$libs/token';

import { type BridgeType, BridgeTypes } from './types';

// Note: we could combine this with Context API, but since we'll only
// have one Bridge component, it would be an overkill. If we wanted to
// instantiate multiple Bridge components, then we'd need to use
// Context API to avoid having multiple instances of the same store.
// One could argue that we only want this store to be used by the Bridge
// and its descendants, in which case Context API would be the one to use,
// but once again, we don't need such level of security that we have to
// prevent other components outside the Bridge from accessing this store.

export const activeBridge = writable<BridgeType>(BridgeTypes.FUNGIBLE);
export const selectedToken = writable<Maybe<Token | NFT>>(null);
export const selectedNFTs = writable<Maybe<NFT[]>>(null);
export const tokenBalance = writable<Maybe<GetBalanceReturnType>>(null);
export const enteredAmount = writable<bigint>(BigInt(0));
export const destNetwork = writable<Maybe<Chain>>(null);
export const destOptions = writable<Chain[]>(chains);
export const processingFee = writable<bigint>(BigInt(0));
export const processingFeeMethod = writable<ProcessingFeeMethod>(ProcessingFeeMethod.RECOMMENDED);
export const recipientAddress = writable<Maybe<Address>>(null);

// Loading state
export const bridging = writable<boolean>(false);
export const approving = writable<boolean>(false);
export const computingBalance = writable<boolean>(false);
export const validatingAmount = writable<boolean>(false);

// Errors state
export const errorComputingBalance = writable<boolean>(false);

// There are two possible errors that can happen when the user
// enters an amount:
// 1. Insufficient balance
// 2. Insufficient allowance
// The first one is an error and the user cannot proceed. The second one
// is a warning but the user must approve allowance before bridging
export const insufficientBalance = writable<boolean>(false);
export const insufficientAllowance = writable<boolean>(false);

export const allApproved = writable(<boolean>false);
export const selectedTokenIsBridged = writable(<boolean>false);

// Derived state
export const bridgeService = derived(selectedToken, (token) => (token ? bridges[token.type] : null));

export const importDone = writable<boolean>(false);
