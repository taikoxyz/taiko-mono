import { BigNumber, BigNumberish } from "ethers";

type BlockMetadata = {
    id: number;
    l1Height: number;
    l1Hash: string;
    beneficiary: string;
    txListHash: string;
    mixHash: string;
    extraData: string;
    gasLimit: BigNumberish;
    timestamp: number;
    commitSlot: number;
    commitHeight: number;
};

type ForkChoice = {
    provenAt: BigNumber;
    provers: string[];
    blockHash: string;
};

type BlockInfo = {
    proposedAt: number;
    provenAt: number;
    id: number;
    parentHash: string;
    blockHash: string;
    forkChoice: ForkChoice;
    deposit: BigNumber;
    proposer: string;
};

export { BlockMetadata, ForkChoice, BlockInfo };
