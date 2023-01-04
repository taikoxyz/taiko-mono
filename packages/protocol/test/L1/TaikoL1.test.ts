import { expect } from "chai";
import { BigNumber, ContractTransaction, ethers as ethersLib } from "ethers";
import { ethers } from "hardhat";
import RLP from "rlp";
import { TaikoL1, TaikoL2 } from "../../typechain";

describe("TaikoL1", function () {
    let taikoL1: TaikoL1;
    let genesisHash: string;

    beforeEach(async function () {
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const libReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy();

        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy();

        const libZKP = await (
            await ethers.getContractFactory("LibZKP")
        ).deploy();

        const v1Proposing = await (
            await ethers.getContractFactory("V1Proposing")
        ).deploy();

        const v1Proving = await (
            await ethers.getContractFactory("V1Proving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                    LibZKP: libZKP.address,
                },
            })
        ).deploy();

        const v1Verifying = await (
            await ethers.getContractFactory("V1Verifying")
        ).deploy();

        genesisHash = randomBytes32();
        taikoL1 = await (
            await ethers.getContractFactory("TaikoL1", {
                libraries: {
                    V1Verifying: v1Verifying.address,
                    V1Proposing: v1Proposing.address,
                    V1Proving: v1Proving.address,
                },
            })
        ).deploy();
        await taikoL1.init(addressManager.address, genesisHash);
    });

    describe("getLatestSyncedHeader()", async function () {
        it("should be genesisHash because no headers have been synced", async function () {
            const hash = await taikoL1.getLatestSyncedHeader();
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("getSyncedHeader()", async function () {
        it("should revert because header number has not been synced", async function () {
            await expect(taikoL1.getSyncedHeader(1)).to.be.revertedWith(
                "L1:id"
            );
        });

        it("should return appropraite hash for header", async function () {
            const hash = await taikoL1.getSyncedHeader(0);
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("getBlockProvers()", async function () {
        it("should return empty list when there is no proof for that block", async function () {
            const provers = await taikoL1.getBlockProvers(
                Math.ceil(Math.random() * 1024),
                randomBytes32()
            );

            expect(provers).to.be.empty;
        });
    });

    describe("halt()", async function () {
        it("should revert called by nonOwner", async function () {
            const initiallyHalted = await taikoL1.isHalted();
            expect(initiallyHalted).to.be.eq(false);
            const signers = await ethers.getSigners();
            await expect(
                taikoL1.connect(signers[1]).halt(true)
            ).to.be.revertedWith("Ownable: caller is not the owner");

            const isHalted = await taikoL1.isHalted();
            expect(isHalted).to.be.eq(false);
        });

        it("should not revert when called by owner", async function () {
            const initiallyHalted = await taikoL1.isHalted();
            expect(initiallyHalted).to.be.eq(false);
            await taikoL1.halt(true);
            const isHalted = await taikoL1.isHalted();
            expect(isHalted).to.be.eq(true);
        });
    });

    describe("proposeBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1:inputs:size");
        });

        it("should revert when halted", async function () {
            await taikoL1.halt(true);
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("0x1");
        });
    });

    describe("commitBlock()", async function () {
        it("should revert when size of inputs is les than 2", async function () {
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("L1:inputs:size");
        });

        it("should revert when halted", async function () {
            await taikoL1.halt(true);
            await expect(
                taikoL1.proposeBlock([randomBytes32()])
            ).to.be.revertedWith("0x1");
        });
    });

    describe("whitelisting()", async function () {
        it("proposers", async function () {
            const proposer = (await ethers.getSigners())[1];
            await taikoL1.enableWhitelisting(true, true);
            const initIsWhitelisted = await taikoL1.isProposerWhitelisted(
                proposer.address
            );
            expect(initIsWhitelisted).to.be.eq(false);

            await taikoL1.whitelistProposer(proposer.address, true);

            const isWhitelisted = await taikoL1.isProposerWhitelisted(
                proposer.address
            );
            expect(isWhitelisted).to.be.eq(true);

            await taikoL1.whitelistProposer(proposer.address, false);

            const isWhitelistAfterDelisting =
                await taikoL1.isProposerWhitelisted(proposer.address);
            expect(isWhitelistAfterDelisting).to.be.eq(false);
        });

        it("proposers", async function () {
            const prover = (await ethers.getSigners())[1];
            await taikoL1.enableWhitelisting(true, true);
            const initIsWhitelisted = await taikoL1.isProverWhitelisted(
                prover.address
            );
            expect(initIsWhitelisted).to.be.eq(false);

            await taikoL1.whitelistProver(prover.address, true);

            const isWhitelisted = await taikoL1.isProverWhitelisted(
                prover.address
            );
            expect(isWhitelisted).to.be.eq(true);

            await taikoL1.whitelistProver(prover.address, false);

            const isWhitelistAfterDelisting = await taikoL1.isProverWhitelisted(
                prover.address
            );
            expect(isWhitelistAfterDelisting).to.be.eq(false);
        });
    });
});

describe("integration: TaikoL1", function () {
    let taikoL1: TaikoL1;
    let taikoL2: TaikoL2;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l2Signer: ethersLib.Signer;

    beforeEach(async function () {
        l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        l2Signer = await l2Provider.getSigner(
            "0x4D9E82AC620246f6782EAaBaC3E3c86895f3f0F8"
        );

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const libReceiptDecoder = await (
            await ethers.getContractFactory("LibReceiptDecoder")
        ).deploy();

        const libTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        ).deploy();

        const libZKP = await (
            await ethers.getContractFactory("LibZKP")
        ).deploy();

        const v1Proposing = await (
            await ethers.getContractFactory("V1Proposing")
        ).deploy();

        const v1Proving = await (
            await ethers.getContractFactory("V1Proving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                    LibZKP: libZKP.address,
                },
            })
        ).deploy();

        const v1Verifying = await (
            await ethers.getContractFactory("V1Verifying")
        ).deploy();

        const l2AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        )
            .connect(l2Signer)
            .deploy();
        await l2AddressManager.init();

        // Deploying TaikoL2 Contract linked with LibTxDecoder (throws error otherwise)
        const l2LibTxDecoder = await (
            await ethers.getContractFactory("LibTxDecoder")
        )
            .connect(l2Signer)
            .deploy();

        taikoL2 = await (
            await ethers.getContractFactory("TaikoL2", {
                libraries: {
                    LibTxDecoder: l2LibTxDecoder.address,
                },
            })
        )
            .connect(l2Signer)
            .deploy(l2AddressManager.address);

        const genesisHash = taikoL2.deployTransaction.blockHash;

        taikoL1 = await (
            await ethers.getContractFactory("TaikoL1", {
                libraries: {
                    V1Verifying: v1Verifying.address,
                    V1Proposing: v1Proposing.address,
                    V1Proving: v1Proving.address,
                },
            })
        ).deploy();
        await taikoL1.init(addressManager.address, genesisHash as string);
    });

    describe("isCommitValid()", async function () {
        it("should not be valid", async function () {
            const block = await l2Provider.getBlock("latest");
            const txListHash = ethers.utils.keccak256(
                RLP.encode(block.transactions)
            );
            const hash = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [block.miner, txListHash]
                )
            );

            const isCommitValid = await taikoL1.isCommitValid(1, 1, hash);

            expect(isCommitValid).to.be.eq(false);
        });
    });

    describe("getProposedBlock()", function () {
        it("proposed block does not exist", async function () {
            const block = await taikoL1.getProposedBlock(123);
            expect(block[0]).to.be.eq(ethers.constants.HashZero);
            expect(block[1]).to.be.eq(ethers.constants.AddressZero);
            expect(block[2]).to.be.eq(BigNumber.from(0));
        });
    });
    describe("commitBlock() -> proposeBlock() integration", async function () {
        it("should revert with invalid meta", async function () {
            const block = await l2Provider.getBlock("latest");
            const txListHash = ethers.utils.keccak256(
                RLP.encode(block.transactions)
            );
            const hash = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [block.miner, txListHash]
                )
            );
            let tx: ContractTransaction;
            expect((tx = await taikoL1.commitBlock(1, hash))).to.emit(
                taikoL1,
                "BlockCommitted"
            );

            // blockMetadata is inputs[0], txListBytes = inputs[1]
            const inputs = [];
            const meta = {
                id: 1, // invalid because id should be 0
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 1,
                commitHeight: tx.blockNumber,
            };

            const blockMetadataBytes = ethers.utils.defaultAbiCoder.encode(
                [
                    "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
                ],
                [meta]
            );

            inputs[0] = blockMetadataBytes;
            inputs[1] = RLP.encode(block.transactions);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:placeholder"
            );
        });

        it("should revert with invalid gasLimit", async function () {
            const block = await l2Provider.getBlock("latest");
            const txListHash = ethers.utils.keccak256(
                RLP.encode(block.transactions)
            );
            const hash = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [block.miner, txListHash]
                )
            );
            let tx: ContractTransaction;
            expect((tx = await taikoL1.commitBlock(1, hash))).to.emit(
                taikoL1,
                "BlockCommitted"
            );

            // blockMetadata is inputs[0], txListBytes = inputs[1]
            const inputs = [];
            const meta = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: BigNumber.from(process.env.K_BLOCK_MAX_GAS_LIMIT).add(
                    1
                ),
                timestamp: 0,
                commitSlot: 1,
                commitHeight: tx.blockNumber,
            };

            const blockMetadataBytes = ethers.utils.defaultAbiCoder.encode(
                [
                    "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
                ],
                [meta]
            );

            inputs[0] = blockMetadataBytes;
            inputs[1] = RLP.encode(block.transactions);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:gasLimit"
            );
        });

        it("should revert with invalid gasLimit", async function () {
            const block = await l2Provider.getBlock("latest");
            const txListHash = ethers.utils.keccak256(
                RLP.encode(block.transactions)
            );
            const hash = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [block.miner, txListHash]
                )
            );
            let tx: ContractTransaction;
            expect((tx = await taikoL1.commitBlock(1, hash))).to.emit(
                taikoL1,
                "BlockCommitted"
            );

            // blockMetadata is inputs[0], txListBytes = inputs[1]
            const inputs = [];
            const meta = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: ethers.utils.hexlify(ethers.utils.randomBytes(33)), // invalid extradata
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 1,
                commitHeight: tx.blockNumber,
            };

            const blockMetadataBytes = ethers.utils.defaultAbiCoder.encode(
                [
                    "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
                ],
                [meta]
            );

            inputs[0] = blockMetadataBytes;
            inputs[1] = RLP.encode(block.transactions);

            await expect(taikoL1.proposeBlock(inputs)).to.be.revertedWith(
                "L1:extraData"
            );
        });

        it("should commit and be able to propose", async function () {
            const block = await l2Provider.getBlock("latest");
            const txListHash = ethers.utils.keccak256(
                RLP.encode(block.transactions)
            );
            const hash = ethers.utils.keccak256(
                ethers.utils.solidityPack(
                    ["address", "bytes32"],
                    [block.miner, txListHash]
                )
            );
            let tx: ContractTransaction;
            expect((tx = await taikoL1.commitBlock(1, hash))).to.emit(
                taikoL1,
                "BlockCommitted"
            );

            // blockMetadata is inputs[0], txListBytes = inputs[1]
            const inputs = [];
            const meta = {
                id: 0,
                l1Height: 0,
                l1Hash: ethers.constants.HashZero,
                beneficiary: block.miner,
                txListHash: txListHash,
                mixHash: ethers.constants.HashZero,
                extraData: block.extraData,
                gasLimit: block.gasLimit,
                timestamp: 0,
                commitSlot: 1,
                commitHeight: tx.blockNumber,
            };

            const blockMetadataBytes = ethers.utils.defaultAbiCoder.encode(
                [
                    "tuple(uint256 id, uint256 l1Height, bytes32 l1Hash, address beneficiary, bytes32 txListHash, bytes32 mixHash, bytes extraData, uint64 gasLimit, uint64 timestamp, uint64 commitHeight, uint64 commitSlot)",
                ],
                [meta]
            );

            inputs[0] = blockMetadataBytes;
            inputs[1] = RLP.encode(block.transactions);

            expect(await taikoL1.proposeBlock(inputs)).to.emit(
                taikoL1,
                "BlockProposed"
            );

            const stateVariables = await taikoL1.getStateVariables();
            const proposedBlock = await taikoL1.getProposedBlock(
                stateVariables[3].sub(1)
            );

            expect(proposedBlock[0]).not.to.be.eq(ethers.constants.HashZero);
            expect(proposedBlock[1]).not.to.be.eq(ethers.constants.AddressZero);
            expect(proposedBlock[2]).not.to.be.eq(BigNumber.from(0));

            const isCommitValid = await taikoL1.isCommitValid(
                1,
                tx.blockNumber as number,
                hash
            );

            expect(isCommitValid).to.be.eq(true);
        });
    });
});

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
}
