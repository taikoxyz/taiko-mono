import { BigNumber as EBN } from "ethers"

interface L2BlockHeader {
    parentHash: string
    ommersHash: string
    beneficiary: string
    stateRoot: string
    transactionsRoot: string
    receiptsRoot: string
    logsBloom: any[]
    difficulty: EBN
    height: EBN
    gasLimit: EBN
    gasUsed: EBN
    timestamp: EBN
    extraData: any[]
    mixHash: string
    nonce: EBN
}

interface L2BlockExtra {
    dataHash: string
    l1SignalRoot: string
    l2SignalRoot: string
    l1BlockHash: string
    l1BlockHeight: EBN
    proposedAt: EBN
    validator: string
    blocktimeTarget: EBN
}

export interface L2Block {
    header: L2BlockHeader
    extra: L2BlockExtra
    headerHash: string
    parentHash: string
    validatorSig: any[]
}
