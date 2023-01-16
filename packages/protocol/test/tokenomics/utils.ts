import { BigNumber, ethers } from "ethers";
import { TaikoL1, TkoToken } from "../../typechain";
import Proposer from "../utils/proposer";

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

    console.log("-----------PROPOSED---------------", block.number, id);

    blockIdsToNumber[id.toString()] = block.number;

    const newProofReward = await taikoL1.getProofReward(
        new Date().getMilliseconds(),
        meta.timestamp
    );

    console.log(
        "NEW PROOF REWARD",
        ethers.utils.formatEther(newProofReward.toString()),
        " TKO"
    );

    const newProposerTkoBalance = await tkoTokenL1.balanceOf(
        await proposerSigner.getAddress()
    );

    console.log(
        "NEW PROPOSER TKO BALANCE",
        ethers.utils.formatEther(newProposerTkoBalance.toString()),
        " TKO"
    );

    const newBlockFee = await taikoL1.getBlockFee();

    console.log(
        "NEW BLOCK FEE",
        ethers.utils.formatEther(newBlockFee.toString()),
        " TKO"
    );
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

export { sendTinyEtherToZeroAddress, onNewL2Block };
