import { ethers } from "ethers";
import RLP from "rlp";
import { TaikoL1 } from "../../typechain";
import { BlockProposedEvent } from "../../typechain/LibProposing";
import { proposeBlock } from "./propose";
import { sendTinyEtherToZeroAddress } from "./seed";


const proposeLatestBlock = async (
    taikoL1: TaikoL1,
    l1Signer: any,
    l2Provider: ethers.providers.JsonRpcProvider,
) => {
    const block = await l2Provider.getBlock("latest");


    const proposeReceipt = await proposeBlock(
        taikoL1.connect(l1Signer),
        block,
        block.gasLimit,
    );

    const proposedEvent: BlockProposedEvent = (
        proposeReceipt.events as any[]
    ).find((e) => e.event === "BlockProposed");

    return { proposedEvent, proposeReceipt, block };
};

export { proposeLatestBlock };
