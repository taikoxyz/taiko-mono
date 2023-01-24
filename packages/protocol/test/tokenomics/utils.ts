import { BigNumber, ethers } from "ethers";
import { TaikoL1, TkoToken } from "../../typechain";
import Proposer from "../utils/proposer";
import sleep from "../utils/sleep";

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
};

async function sleepUntilBlockIsVerifiable(
    taikoL1: TaikoL1,
    id: number,
    provenAt: number
) {
    const delay = await taikoL1.getUncleProofDelay(id);
    const delayInMs = delay.mul(1000);
    await sleep(delayInMs.toNumber());
}
async function onNewL2Block(
    l2Provider: ethers.providers.JsonRpcProvider,
    blockNumber: number,
    proposer: Proposer,
    blockIdsToNumber: any,
    taikoL1: TaikoL1,
    proposerSigner: any,
    tkoTokenL1: TkoToken
): Promise<{
    newProposerTkoBalance: BigNumber;
    newBlockFee: BigNumber;
    newProofReward: BigNumber;
}> {
    const block = await l2Provider.getBlock(blockNumber);
    const receipt = await proposer.commitThenProposeBlock(block);
    const proposedEvent = (receipt.events as any[]).find(
        (e) => e.event === "BlockProposed"
    );

    const { id, meta } = (proposedEvent as any).args;

    blockIdsToNumber[id.toString()] = block.number;

    const newProofReward = await taikoL1.getProofReward(
        new Date().getMilliseconds(),
        meta.timestamp
    );

    const newProposerTkoBalance = await tkoTokenL1.balanceOf(
        await proposerSigner.getAddress()
    );

    const newBlockFee = await taikoL1.getBlockFee();

    return { newProposerTkoBalance, newBlockFee, newProofReward };
}

const sendTinyEtherToZeroAddress = async (signer: any) => {
    await signer
        .sendTransaction({
            to: ethers.constants.AddressZero,
            value: BigNumber.from(1),
        })
        .wait(1);
};

export {
    sendTinyEtherToZeroAddress,
    onNewL2Block,
    sleepUntilBlockIsVerifiable,
};
export type { BlockInfo, ForkChoice };
