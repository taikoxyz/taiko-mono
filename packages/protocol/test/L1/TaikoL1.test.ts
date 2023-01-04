import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { TaikoL1 } from "../../typechain";

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

        const libProposing = await (
            await ethers.getContractFactory("LibProposing")
        ).deploy();

        const libProving = await (
            await ethers.getContractFactory("LibProving", {
                libraries: {
                    LibReceiptDecoder: libReceiptDecoder.address,
                    LibTxDecoder: libTxDecoder.address,
                },
            })
        ).deploy();

        const libVerifying = await (
            await ethers.getContractFactory("LibVerifying")
        ).deploy();

        genesisHash = randomBytes32();
        const feeBase = BigNumber.from(10).pow(18);
        taikoL1 = await (
            await ethers.getContractFactory("TestTaikoL1", {
                libraries: {
                    LibVerifying: libVerifying.address,
                    LibProposing: libProposing.address,
                    LibProving: libProving.address,
                },
            })
        ).deploy();
        await taikoL1.init(addressManager.address, genesisHash, feeBase);
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

    describe("getDelayForBlockId()", async function () {
        it("should return  initial uncle delay for block id <= 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConfig();
            const maxNumBlocks = constants[1];
            const delay = await taikoL1.getDelayForBlockId(maxNumBlocks.mul(2));
            const initialUncleDelay = 60;
            expect(delay).to.be.eq(initialUncleDelay);
        });

        it("should return avg proof time for block id > 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConfig();
            const maxNumBlocks = constants[1];
            const delay = await taikoL1.getDelayForBlockId(
                maxNumBlocks.mul(2).add(1)
            );
            const avgProofTime = 0; // no proofs have been generated
            expect(delay).to.be.eq(avgProofTime);
        });
    });
});

function randomBytes32() {
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
}
