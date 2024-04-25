//import * as Icons from 'svelte-awesome-icons'

export type { IconType } from '$components/core/Icons'

//export type IconType = keyof typeof Icons

export interface IDropdownItem {
    icon: IconType
    label: string
    href: string
}

export type IChainId = 31337 | 17000

export interface IBid {
    amount: number
    bidder: IAddress
    id: string
    timestamp: Date
}

export interface IAuction {
    id: number
    tokenId: number
    amount: number
    startTime: Date
    endTime: Date
    bidder: string
    settled: boolean
    //minBid: number
    bids: IBid[]
    blockNumber: number
    lastUpdate: Date
    updateCounter: number
}

export type IAddress = `0x${string}`

export interface ITaikoon {
    id: number
    owner: IAddress
    mintPrice: number
    mintedAt: Date
    isAuctioned: boolean
    isFreeMint: boolean
    isPaidMint: boolean
}
