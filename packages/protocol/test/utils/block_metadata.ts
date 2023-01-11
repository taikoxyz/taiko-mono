import { BigNumberish } from "ethers";

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

export { BlockMetadata };
