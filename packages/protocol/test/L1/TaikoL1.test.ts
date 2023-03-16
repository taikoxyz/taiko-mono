import { expect } from "chai";
import { ethers } from "hardhat";
import { TaikoL1 } from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import { randomBytes32 } from "../utils/bytes";
import { deployTaikoL1 } from "../utils/taikoL1";

describe("TaikoL1", function () {
    let taikoL1: TaikoL1;
    let genesisHash: string;

    beforeEach(async function () {
        const l1Signer = (await ethers.getSigners())[0];
        const addressManager = await deployAddressManager(l1Signer);
        genesisHash = randomBytes32();
        taikoL1 = await deployTaikoL1(addressManager, genesisHash, false);
    });

    describe("getXchainBlockHash(0)", async function () {
        it("should be genesisHash because no headers have been synced", async function () {
            const hash = await taikoL1.getXchainBlockHash(0);
            expect(hash).to.be.eq(genesisHash);
        });
    });

    describe("getXchainBlockHash()", async function () {
        it("should revert because header number has not been synced", async function () {
            await expect(taikoL1.getXchainBlockHash(1)).to.be.revertedWith(
                "L1_BLOCK_NUMBER()"
            );
        });

        it("should return appropraite hash for header", async function () {
            const hash = await taikoL1.getXchainBlockHash(0);
            expect(hash).to.be.eq(genesisHash);
        });
    });
});
