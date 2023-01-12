import { expect } from "chai";
import { ethers } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import { TaikoL1, TaikoL2 } from "../../typechain";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import Proposer from "../utils/proposer";
import sleep from "../utils/sleep";
import { defaultFeeBase, deployTaikoL1 } from "../utils/taikoL1";
import { deployTaikoL2 } from "../utils/taikoL2";
import deployTkoToken from "../utils/tkoToken";
import sendTransaction from "../utils/transaction";

describe("tokenomics", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l1Provider: ethers.providers.JsonRpcProvider;
    let l2Provider: ethers.providers.JsonRpcProvider;
    let l1Signer: any;
    let l2Signer: any;
    let proposerSigner: any;
    let proverSigner: any;
    let genesisHeight: number;
    let genesisHash: string;
    let tkoTokenL1: TestTkoToken;

    beforeEach(async () => {
        l1Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:18545"
        );

        l1Provider.pollingInterval = 100;

        const signers = await hardhatEthers.getSigners();
        l1Signer = signers[0];

        l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        l2Signer = await l2Provider.getSigner(
            (
                await l2Provider.listAccounts()
            )[0]
        );

        taikoL2 = await deployTaikoL2(l2Signer);

        genesisHash = taikoL2.deployTransaction.blockHash as string;
        genesisHeight = taikoL2.deployTransaction.blockNumber as number;

        const { taikoL1: tL1, addressManager } = await deployTaikoL1(
            genesisHash,
            true,
            defaultFeeBase
        );

        taikoL1 = tL1;

        const { chainId } = await l1Provider.getNetwork();

        proposerSigner = ethers.Wallet.createRandom().connect(l1Provider);
        proverSigner = ethers.Wallet.createRandom().connect(l1Provider);
        await l1Signer.sendTransaction({
            to: await proposerSigner.getAddress(),
            value: ethers.utils.parseEther("1"),
        });

        await l1Signer.sendTransaction({
            to: await proverSigner.getAddress(),
            value: ethers.utils.parseEther("1"),
        });

        const balance = await proposerSigner.getBalance();
        expect(balance).to.be.eq(ethers.utils.parseEther("1"));

        tkoTokenL1 = await deployTkoToken(l1Signer, taikoL1.address);

        await addressManager.setAddress(
            `${chainId}.tko_token`,
            tkoTokenL1.address
        );

        await tkoTokenL1
            .connect(l1Signer)
            .mintAnyone(
                await proposerSigner.getAddress(),
                ethers.utils.parseEther("100")
            );

        expect(
            await tkoTokenL1.balanceOf(await proposerSigner.getAddress())
        ).to.be.eq(ethers.utils.parseEther("100"));

        // set up interval mining so we always get new blocks
        await l2Provider.send("evm_setIntervalMining", [2000]);

        // send transactions to L1 so we always get new blocks
        setInterval(async () => await sendTransaction(l1Signer), 1 * 500);
    });

    it("tests tokenomics, propose blocks, blockFee should increase", async function () {
        const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
        const blockIdsToNumber: any = {};

        const proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            commitConfirmations.toNumber(),
            maxNumBlocks.toNumber(),
            0
        );

        // const initialBlockFee = await taikoL1.getBlockFee();

        // expect(initialBlockFee).not.to.be.eq(0);

        l2Provider.on("block", async (blockNumber) => {
            if (blockNumber <= genesisHeight) return;
            try {
                const block = await l2Provider.getBlock(blockNumber);
                const receipt = await proposer.commitThenProposeBlock(block);
                expect(receipt.status).to.be.eq(1);
                const proposedEvent = (receipt.events as any[]).find(
                    (e) => e.event === "BlockProposed"
                );

                const { id } = (proposedEvent as any).args;
                console.log(
                    "-----------PROPOSED---------------",
                    block.number,
                    id
                );
                blockIdsToNumber[id.toString()] = block.number;
            } catch (e) {
                console.error(e);
                expect(true).to.be.eq(false);
            }
        });

        await sleep(30 * 1000);

        // const newBlockFee = await taikoL1.getBlockFee();
        // expect(newBlockFee.gt(initialBlockFee)).to.be.eq(true);
    });

    // it("tests tokenomics, propose blocks and prove blocks on interval, proverReward should decline and blockFee should increase", async function () {
    //     const { maxNumBlocks, commitConfirmations } = await taikoL1.getConfig();
    //     const blockIdsToNumber: any = {};

    //     const proposer = new Proposer(
    //         taikoL1.connect(proposerSigner),
    //         l2Provider,
    //         commitConfirmations.toNumber(),
    //         maxNumBlocks.toNumber(),
    //         0
    //     );

    //     const prover: Prover = new Prover(taikoL1.connect(proverSigner));

    //     l2Provider.on("block", async (blockNumber) => {
    //         if (blockNumber <= genesisHeight) return;
    //         try {
    //             console.log("new block", blockNumber);
    //             const block = await l2Provider.getBlock(blockNumber);
    //             const receipt = await proposer.commitThenProposeBlock(block);
    //             expect(receipt.status).to.be.eq(1);
    //             const proposedEvent = (receipt.events as any[]).find(
    //                 (e) => e.event === "BlockProposed"
    //             );

    //             const { id } = (proposedEvent as any).args;
    //             console.log(
    //                 "-----------PROPOSED---------------",
    //                 block.number,
    //                 id
    //             );
    //             blockIdsToNumber[id.toString()] = block.number;
    //         } catch (e) {
    //             console.error(e);
    //             expect(true).to.be.eq(false);
    //         }
    //     });

    //     taikoL1.on(
    //         "BlockProposed",
    //         async (id: BigNumber, meta: BlockMetadata) => {
    //             console.log("proving block: id", id.toString());
    //             try {
    //                 await proveBlock(
    //                     taikoL1,
    //                     taikoL2,
    //                     l1Provider,
    //                     l2Provider,
    //                     await proverSigner.getAddress(),
    //                     id.toNumber(),
    //                     blockIdsToNumber[id.toString()],
    //                     meta
    //                 );
    //             } catch (e) {
    //                 console.error(e);
    //                 throw e;
    //             }
    //         }
    //     );

    //     await sleep(60 * 1000);
    // });
});
