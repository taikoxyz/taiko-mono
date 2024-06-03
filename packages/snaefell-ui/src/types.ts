import type { Address } from 'viem';

import type { IconType } from '$components/core/Icons';
export type { IconType } from '$components/core/Icons';

export interface IDropdownItem {
  icon: IconType;
  label: string;
  href: string;
}

export type IChainId =
  | 167000 // taiko
  | 31337; // hardhat

export interface IBid {
  amount: number;
  bidder: IAddress;
  id: string;
  timestamp: Date;
}

export interface IAuction {
  id: number;
  tokenId: number;
  amount: number;
  startTime: Date;
  endTime: Date;
  bidder: string;
  settled: boolean;
  //minBid: number
  bids: IBid[];
  blockNumber: number;
  lastUpdate: Date;
  updateCounter: number;
}

export type IAddress = Address;

export interface ITaikoon {
  id: number;
  owner: IAddress;
  mintPrice: number;
  mintedAt: Date;
  isAuctioned: boolean;
  isFreeMint: boolean;
  isPaidMint: boolean;
}
