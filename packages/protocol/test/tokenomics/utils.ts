import { BigNumber, ethers } from "ethers";
import { ConfigManager, TaikoL1, TkoToken } from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import Proposer from "../utils/proposer";
import {
    getDefaultL2Signer,
    getL1Provider,
    getL2Provider,
} from "../utils/provider";
import createAndSeedWallets from "../utils/seed";
import sleep from "../utils/sleep";
import { defaultFeeBase, deployTaikoL1 } from "../utils/taikoL1";
import { deployTaikoL2 } from "../utils/taikoL2";
import deployTkoToken from "../utils/tkoToken";
import { ethers as hardhatEthers } from "hardhat";

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
    await sleep(5 * delayInMs.toNumber());
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

async function initTokenomicsFixture() {
    const l1Provider = getL1Provider();

    l1Provider.pollingInterval = 100;

    const signers = await hardhatEthers.getSigners();
    const l1Signer = signers[0];

    const l2Provider = getL2Provider();

    const l2Signer = await getDefaultL2Signer();

    const l2AddressManager = await deployAddressManager(l2Signer);
    const taikoL2 = await deployTaikoL2(l2Signer, l2AddressManager, false);

    const genesisHash = taikoL2.deployTransaction.blockHash as string;
    const genesisHeight = taikoL2.deployTransaction.blockNumber as number;

    const l1AddressManager = await deployAddressManager(l1Signer);
    const taikoL1 = await deployTaikoL1(
        l1AddressManager,
        genesisHash,
        true,
        defaultFeeBase
    );
    const { chainId } = await l1Provider.getNetwork();

    const [proposerSigner, proverSigner] = await createAndSeedWallets(
        2,
        l1Signer
    );

    const tkoTokenL1 = await deployTkoToken(
        l1Signer,
        l1AddressManager,
        taikoL1.address
    );

    await (
        await l1AddressManager.setAddress(
            `${chainId}.tko_token`,
            tkoTokenL1.address
        )
    ).wait(1);

    const { chainId: l2ChainId } = await l2Provider.getNetwork();

    await (
        await l1AddressManager.setAddress(`${l2ChainId}.taiko`, taikoL2.address)
    ).wait(1);

    await (
        await l1AddressManager.setAddress(
            `${chainId}.proof_verifier`,
            taikoL1.address
        )
    ).wait(1);

    const configManager: ConfigManager = await (
        await hardhatEthers.getContractFactory("ConfigManager")
    )
        .connect(l1Signer)
        .deploy();
    await configManager.deployed();

    await l1AddressManager.setAddress(
        `${chainId}.config_manager`,
        configManager.address
    );

    const mintTx = await tkoTokenL1
        .connect(l1Signer)
        .mintAnyone(
            await proposerSigner.getAddress(),
            ethers.utils.parseEther("100")
        );

    await mintTx.wait(1);

    // set up interval mining so we always get new blocks
    await l2Provider.send("evm_setAutomine", [true]);

    // send transactions to L1 so we always get new blocks
    const interval = setInterval(
        async () => await sendTinyEtherToZeroAddress(l1Signer),
        1 * 1000
    );

    const tx = await l2Signer.sendTransaction({
        to: proverSigner.address,
        value: ethers.utils.parseUnits("1", "ether"),
    });
    await tx.wait(1);

    return {
        taikoL1,
        taikoL2,
        l1Provider,
        l2Provider,
        l1Signer,
        l2Signer,
        proposerSigner,
        proverSigner,
        genesisHeight,
        genesisHash,
        tkoTokenL1,
        l1AddressManager,
        interval,
    };
}
export {
    sendTinyEtherToZeroAddress,
    onNewL2Block,
    sleepUntilBlockIsVerifiable,
    initTokenomicsFixture,
};

export type { BlockInfo, ForkChoice };
