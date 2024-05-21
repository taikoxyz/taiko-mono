import { writable } from 'svelte/store';

export interface ITaikoonDetailStore {
  tokenId: number;
  isModalOpen: boolean;
}

export const taikoonDetail = writable<ITaikoonDetailStore>();

export type ITaikoonDetail = typeof taikoonDetail;
