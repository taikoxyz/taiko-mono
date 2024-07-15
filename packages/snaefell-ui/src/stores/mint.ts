import { writable } from 'svelte/store';

import type { IAddress } from '../types';

export interface IMintStore {
  isModalOpen: boolean;
  isMinting: boolean;
  tokenIds: number[];
  address: IAddress;
  totalMintCount: number;
  txHash: string;
}

export const mint = writable<IMintStore>();

export type IMint = typeof mint;
