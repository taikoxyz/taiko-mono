import { expect } from "chai";
import { ethers } from "hardhat";
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

    describe("getDelayForBlockId()", async function () {
        it("should return  initial uncle delay for block id <= 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConstants();
            const maxNumBlocks = constants[2];
            const delay = await taikoL1.getDelayForBlockId(maxNumBlocks.mul(2));
            const initialUncleDelay = 3600;
            expect(delay).to.be.eq(initialUncleDelay);
        });

        it("should return avg proof time for block id > 2 * K_MAX_NUM_BLOCKS", async function () {
            const constants = await taikoL1.getConstants();
            const maxNumBlocks = constants[2];
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
