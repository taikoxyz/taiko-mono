import { expect } from "chai";
import { SimpleChannel } from "channel-ts";
import { BigNumber, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import { TaikoL1, TestTaikoToken } from "../../typechain";
import blockListener from "../utils/blockListener";
import { BlockMetadata } from "../utils/block_metadata";
import {
    commitAndProposeLatestBlock,
    commitBlock,
    generateCommitHash,
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
import {
    commitProposeClaimProveAndVerify,
    verifyBlocks,
} from "../utils/verify";

describe("integration:TaikoL1", function () {
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
            config.commitConfirmations.toNumber(),
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

    describe("isCommitValid()", async function () {
        it("should not be valid if it has not been committed", async function () {
            const block = await l2Provider.getBlock("latest");
            const commit = generateCommitHash(block);

            const isCommitValid = await taikoL1.isCommitValid(
                1,
                1,
                commit.hash
            );

            expect(isCommitValid).to.be.false;
        });

        it("should be valid if it has been committed", async function () {
            const block = await l2Provider.getBlock("latest");
            const commitSlot = 0;
            const { commit, blockCommittedEvent } = await commitBlock(
                taikoL1,
                block,
                commitSlot
            );
            expect(blockCommittedEvent).not.to.be.undefined;

            for (let i = 0; i < config.commitConfirmations.toNumber(); i++) {
                await sendTinyEtherToZeroAddress(l1Signer);
            }

            const isCommitValid = await taikoL1.isCommitValid(
                commitSlot,
                blockCommittedEvent!.blockNumber,
                commit.hash
            );

            expect(isCommitValid).to.be.true;
        });
    });

    describe("getProposedBlock()", function () {
        it("should revert if block is out of range and not a valid proposed block", async function () {
            await readShouldRevertWithCustomError(
                taikoL1.getProposedBlock(123),
                "L1_ID()"
            );
        });

        it("should return valid block if it's been commmited and proposed", async function () {
            const commitSlot = 0;
            const { proposedEvent } = await commitAndProposeLatestBlock(
                taikoL1,
                l1Signer,
                l2Provider,
                commitSlot
            );
            expect(proposedEvent).not.to.be.undefined;
            expect(proposedEvent.args.meta.commitSlot).to.be.eq(commitSlot);

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
            const { proposedEvent, block } = await commitAndProposeLatestBlock(
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

            // commit and propose block, so our provers can prove it.
            const { proposedEvent } = await proposer.commitThenProposeBlock(
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

    describe("commitBlock() -> proposeBlock() integration", async function () {
        it("should fail if a proposed block's placeholder field values are not default", async function () {
            const block = await l2Provider.getBlock("latest");
            const commitSlot = 0;
            const { tx, commit } = await commitBlock(
                taikoL1,
                block,
                commitSlot
            );

            const receipt = await tx.wait(1);

            const meta: BlockMetadata = {
                id: 1,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: commit.beneficiary,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: commitSlot,
                commitHeight: receipt.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);
            const txPromise = (
                await taikoL1.proposeBlock(inputs, { gasLimit: 500000 })
            ).wait(1);
            await txShouldRevertWithCustomError(
                txPromise,

                l1Provider,
                "L1_METADATA_FIELD()"
            );
        });

        it("should revert with invalid gasLimit", async function () {
            const block = await l2Provider.getBlock("latest");
            const config = await taikoL1.getConfig();
            const gasLimit = config.blockMaxGasLimit;

            const { tx, commit } = await commitBlock(taikoL1, block);

            const receipt = await tx.wait(1);
            const meta: BlockMetadata = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: commit.beneficiary,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: gasLimit.add(1),
                timestamp: 0,
                commitSlot: 0,
                commitHeight: receipt.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            const txPromise = (
                await taikoL1.proposeBlock(inputs, { gasLimit: 250000 })
            ).wait(1);
            await txShouldRevertWithCustomError(
                txPromise,
                l1Provider,
                "L1_GAS_LIMIT()"
            );
        });

        it("should revert with invalid extraData", async function () {
            const block = await l2Provider.getBlock("latest");
            const { tx, commit } = await commitBlock(taikoL1, block);

            const meta: BlockMetadata = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: commit.beneficiary,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: ethers.utils.hexlify(ethers.utils.randomBytes(33)), // invalid extradata
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 0,
                commitHeight: tx.blockNumber as number,
            };

            const inputs = buildProposeBlockInputs(block, meta);

            const txPromise = (
                await taikoL1.proposeBlock(inputs, { gasLimit: 500000 })
            ).wait(1);
            await txShouldRevertWithCustomError(
                txPromise,
                l1Provider,
                "L1_EXTRA_DATA()"
            );
        });

        it("should commit and be able to propose", async function () {
            await commitAndProposeLatestBlock(taikoL1, l1Signer, l2Provider, 0);

            const stateVariables = await taikoL1.getStateVariables();
            const nextBlockId = stateVariables.nextBlockId;
            const proposedBlock = await taikoL1.getProposedBlock(
                nextBlockId.sub(1)
            );

            expect(proposedBlock.metaHash).not.to.be.eq(
                ethers.constants.HashZero
            );
            expect(proposedBlock.proposer).not.to.be.eq(
                ethers.constants.AddressZero
            );
            expect(proposedBlock.proposedAt).not.to.be.eq(BigNumber.from(0));
        });

        it("should commit and be able to propose for all available slots, then revert when all slots are taken", async function () {
            // propose blocks and fill up maxNumBlocks number of slots,
            // expect each one to be successful.
            for (let i = 0; i < config.maxNumBlocks.toNumber() - 1; i++) {
                await commitAndProposeLatestBlock(
                    taikoL1,
                    l1Signer,
                    l2Provider,
                    0
                );

                const stateVariables = await taikoL1.getStateVariables();
                const nextBlockId = stateVariables.nextBlockId;
                const proposedBlock = await taikoL1.getProposedBlock(
                    nextBlockId.sub(1)
                );

                expect(proposedBlock.metaHash).not.to.be.eq(
                    ethers.constants.HashZero
                );
                expect(proposedBlock.proposer).not.to.be.eq(
                    ethers.constants.AddressZero
                );
                expect(proposedBlock.proposedAt).not.to.be.eq(
                    BigNumber.from(0)
                );
            }

            // now expect another proposed block to be invalid since all slots are full and none have
            // been proven.
            const { commitConfirmations } = await taikoL1.getConfig();
            const block = await l2Provider.getBlock("latest");
            const { tx: commitBlockTx, commit } = await commitBlock(
                taikoL1.connect(l1Signer),
                block,
                0
            );
            const commitReceipt = await commitBlockTx.wait(1);

            for (let i = 0; i < commitConfirmations.toNumber() + 5; i++) {
                await sendTinyEtherToZeroAddress(l1Signer);
            }

            const meta: BlockMetadata = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: commit.beneficiary,
                txListHash: commit.txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 0,
                commitHeight: commitReceipt.blockNumber,
            };

            await txShouldRevertWithCustomError(
                (
                    await taikoL1.proposeBlock(
                        buildProposeBlockInputs(block, meta),
                        { gasLimit: 500000 }
                    )
                ).wait(),
                l1Provider,
                "L1_TOO_MANY_BLOCKS()"
            );
        });
    });

    describe("getLatestSyncedHeader", function () {
        it("iterates through blockHashHistory length and asserts getLatestSyncedHeader returns correct value", async function () {
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

                const { verifyEvent } = await commitProposeClaimProveAndVerify(
                    taikoL1,
                    l2Provider,
                    blockNumber,
                    proposer,
                    taikoTokenL1,
                    prover
                );

                expect(verifyEvent).not.to.be.undefined;

                const header = await taikoL1.getLatestSyncedHeader();
                expect(header).to.be.eq(verifyEvent.args.blockHash);
                blocks++;
            }
        });
    });

    describe("proveBlock", function () {
        it("reverts when inputs is incorrect length", async function () {
            for (let i = 1; i <= 2; i++) {
                const txPromise = (
                    await taikoL1.proveBlock(
                        1,
                        new Array(i).fill(ethers.constants.HashZero),
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
            }
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

                // commit and propose block, so our provers can prove it.
                const { proposedEvent } = await proposer.commitThenProposeBlock(
                    block
                );

                const header = await getBlockHeader(l2Provider, blockNumber);
                const inputs = buildProveBlockInputs(
                    proposedEvent.args.meta as any as BlockMetadata,
                    header.blockHeader,
                    await prover.getSigner().getAddress(),
                    "0x",
                    "0x"
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

                // commit and propose block, so our provers can prove it.
                const { proposedEvent } = await proposer.commitThenProposeBlock(
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
                inputs[1] = "0x";
                inputs[2] = "0x";

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
