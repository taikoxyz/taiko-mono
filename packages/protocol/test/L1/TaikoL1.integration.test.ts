import { expect } from "chai";
import { SimpleChannel } from "channel-ts";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TestTaikoToken } from "../../typechain";
import blockListener from "../utils/blockListener";
import { BlockMetadata } from "../utils/block_metadata";
import {
    proposeLatestBlock,
} from "../utils/commit";
import { encodeEvidence } from "../utils/encoding";
import {
    readShouldRevertWithCustomError,
    txShouldRevertWithCustomError,
} from "../utils/errors";
import Evidence from "../utils/evidence";
import { initIntegrationFixture } from "../utils/fixture";
import { buildProposeBlockInputs } from "../utils/propose";
import Proposer from "../utils/proposer";
import { buildProveBlockInputs, proveBlock } from "../utils/prove";
import Prover from "../utils/prover";
import { getBlockHeader } from "../utils/rpc";
import { seedTko, sendTinyEtherToZeroAddress } from "../utils/seed";
import { proposeProveAndVerify, verifyBlocks } from "../utils/verify";

describe("integ-----disabled-----ration:TaikoL1", function () {
    let taikoL1: TaikoL1;
    let l1Provider: ethersLib.providers.JsonRpcProvider;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l1Signer: any;
    let proposerSigner: any;
    let genesisHeight: number;
    let taikoTokenL1: TestTaikoToken;
    let chan: SimpleChannel<number>;
    let interval: any;
    let proverSigner: any;
    let proposer: Proposer;
    let prover: Prover;
    /* eslint-disable-next-line */
    let config: Awaited<ReturnType<TaikoL1["getConfig"]>>;

    beforeEach(async function () {
        ({
            l1Provider,
            taikoL1,
            l2Provider,
            l1Signer,
            genesisHeight,
            proposerSigner,
            proverSigner,
            interval,
            chan,
            config,
            taikoTokenL1,
        } = await initIntegrationFixture(false, false));
        proposer = new Proposer(
            taikoL1.connect(proposerSigner),
            l2Provider,
            config.maxNumBlocks.toNumber(),
            0,
            proposerSigner
        );

        prover = new Prover(taikoL1, l2Provider, proverSigner);
    });

    afterEach(() => {
        clearInterval(interval);
        l2Provider.off("block");
        chan.close();
    });

    describe("getProposedBlock()", function () {
        it("should revert if block is out of range and not a valid proposed block", async function () {
            await readShouldRevertWithCustomError(
                taikoL1.getProposedBlock(123),
                "L1_ID()"
            );
        });

        it("should return valid block if it's been commmited and proposed", async function () {
            const { proposedEvent } = await proposeLatestBlock(
                taikoL1,
                l1Signer,
                l2Provider,
            );
            expect(proposedEvent).not.to.be.undefined;

            const proposedBlock = await taikoL1.getProposedBlock(
                proposedEvent.args.meta.id
            );
            expect(proposedBlock).not.to.be.undefined;
            expect(proposedBlock.proposer).to.be.eq(
                await l1Signer.getAddress()
            );
        });
    });

    describe("getForkChoice", function () {
        it("returns no empty fork choice for un-proposed, un-proven and un-verified block", async function () {
            const forkChoice = await taikoL1.getForkChoice(
                1,
                ethers.constants.HashZero
            );
            expect(forkChoice.blockHash).to.be.eq(ethers.constants.HashZero);
            expect(forkChoice.provenAt).to.be.eq(0);
        });

        it("returns populated data for submitted fork choice", async function () {
            const { proposedEvent, block } = await proposeLatestBlock(
                taikoL1,
                l1Signer,
                l2Provider,
                0
            );

            expect(proposedEvent).not.to.be.undefined;
            const proveEvent = await proveBlock(
                taikoL1,
                l2Provider,
                await l1Signer.getAddress(),
                proposedEvent.args.id.toNumber(),
                block.number,
                proposedEvent.args.meta as any as BlockMetadata
            );
            expect(proveEvent).not.to.be.undefined;

            const forkChoice = await taikoL1.getForkChoice(
                proposedEvent.args.id.toNumber(),
                block.parentHash
            );
            expect(forkChoice.blockHash).to.be.eq(block.hash);
            expect(forkChoice.prover).to.be.eq(await l1Signer.getAddress());
        });

        it("returns empty after a block is verified", async function () {
            await seedTko([prover], taikoTokenL1.connect(l1Signer));

            const blockNumber = genesisHeight + 1;
            /* eslint-disable-next-line */
            const block = await l2Provider.getBlock(blockNumber);

            // propose block, so our provers can prove it.
            const { proposedEvent } = await proposer.proposeBlock(
                block
            );

            await prover.prove(
                proposedEvent.args.id.toNumber(),
                blockNumber,
                proposedEvent.args.meta as any as BlockMetadata
            );

            let forkChoice = await taikoL1.getForkChoice(
                proposedEvent.args.id.toNumber(),
                block.parentHash
            );
            expect(forkChoice).not.to.be.undefined;
            expect(forkChoice.prover).to.be.not.eq(
                ethers.constants.AddressZero
            );

            const verifiedEvent = await verifyBlocks(taikoL1, 1);
            expect(verifiedEvent).not.to.be.undefined;

            forkChoice = await taikoL1.getForkChoice(
                proposedEvent.args.id.toNumber(),
                block.parentHash
            );
            expect(forkChoice.prover).to.be.eq(ethers.constants.AddressZero);
        });
    });

    describe("getSyncedBlockHash(0)", function () {
        it("iterates through blockHashHistory length and asserts getSyncedBlockHash(0) returns correct value", async function () {
            l2Provider.on("block", blockListener(chan, genesisHeight));

            let blocks: number = 0;
            // iterate through blockHashHistory twice and try to get latest synced header each time.
            // we modulo the header height by blockHashHistory in the protocol, so
            // this test ensures that logic is sound.
            /* eslint-disable-next-line */
            for await (const blockNumber of chan) {
                if (blocks > config.blockHashHistory.toNumber() * 2 + 1) {
                    chan.close();
                    return;
                }

                const { verifyEvent } = await proposeProveAndVerify(
                    taikoL1,
                    l2Provider,
                    blockNumber,
                    proposer,
                    taikoTokenL1,
                    prover
                );

                expect(verifyEvent).not.to.be.undefined;

                const header = await taikoL1.getSyncedBlockHash(0);
                expect(header).to.be.eq(verifyEvent.args.blockHash);
                blocks++;
            }
        });
    });

    describe("proveBlock", function () {
        it("reverts when inputs is incorrect length", async function () {
            const txPromise = (
                await taikoL1.proveBlock(
                    1,
                    new Array(2).fill(ethers.constants.HashZero), // 1 is the right size
                    {
                        gasLimit: 1000000,
                    }
                )
            ).wait(1);
            await txShouldRevertWithCustomError(
                txPromise,
                l1Provider,
                "L1_INPUT_SIZE()"
            );
        });

        it("reverts when evidence meta id is not the same as the blockId", async function () {
            l2Provider.on("block", blockListener(chan, genesisHeight));

            const config = await taikoL1.getConfig();
            /* eslint-disable-next-line */
            for await (const blockNumber of chan) {
                if (
                    blockNumber >
                    genesisHeight + config.maxNumBlocks.toNumber() - 1
                ) {
                    break;
                }

                const block = await l2Provider.getBlock(blockNumber);

                // propose block, so our provers can prove it.
                const { proposedEvent } = await proposer.proposeBlock(
                    block
                );

                const header = await getBlockHeader(l2Provider, blockNumber);
                const inputs = buildProveBlockInputs(
                    proposedEvent.args.meta as any as BlockMetadata,
                    header.blockHeader,
                    await prover.getSigner().getAddress()
                    // "0x",
                    // "0x"
                );

                const txPromise = (
                    await taikoL1.proveBlock(
                        proposedEvent.args.meta.id.toNumber() + 1, // id different than meta
                        inputs,
                        {
                            gasLimit: 2000000,
                        }
                    )
                ).wait(1);

                await txShouldRevertWithCustomError(
                    txPromise,
                    l1Provider,
                    "L1_ID()"
                );
            }
        });

        it("reverts when prover is the zero address", async function () {
            l2Provider.on("block", blockListener(chan, genesisHeight));

            const config = await taikoL1.getConfig();
            /* eslint-disable-next-line */
            for await (const blockNumber of chan) {
                if (
                    blockNumber >
                    genesisHeight + config.maxNumBlocks.toNumber() - 1
                ) {
                    break;
                }

                const block = await l2Provider.getBlock(blockNumber);

                // propose block, so our provers can prove it.
                const { proposedEvent } = await proposer.proposeBlock(
                    block
                );

                const header = await getBlockHeader(l2Provider, blockNumber);
                const inputs = [];
                const evidence: Evidence = {
                    meta: proposedEvent.args.meta as any as BlockMetadata,
                    header: header.blockHeader,
                    prover: ethers.constants.AddressZero,
                    proofs: [],
                    circuits: [],
                };

                evidence.circuits.push(1);

                for (let i = 0; i < 3; i++) {
                    evidence.proofs.push("0xff");
                }

                inputs[0] = encodeEvidence(evidence);
                // inputs[1] = "0x";
                // inputs[2] = "0x";

                const txPromise = (
                    await taikoL1.proveBlock(
                        proposedEvent.args.meta.id.toNumber(), // id different than meta
                        inputs,
                        {
                            gasLimit: 2000000,
                        }
                    )
                ).wait(1);

                await txShouldRevertWithCustomError(
                    txPromise,
                    l1Provider,
                    "L1_PROVER()"
                );
            }
        });
    });
});
