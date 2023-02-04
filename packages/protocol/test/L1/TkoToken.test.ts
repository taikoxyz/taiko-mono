import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import deployTkoToken from "../utils/tkoToken";
import { TestTkoToken } from "../../typechain/TestTkoToken";
import deployAddressManager from "../utils/addressManager";

describe("TkoToken", function () {
    let owner: any;
    let nonOwner: any;
    let protoBroker: any;
    let token: TestTkoToken;
    let amountMinted: BigNumber;

    before(async function () {
        [owner, nonOwner, protoBroker] = await ethers.getSigners();
    });

    beforeEach(async function () {
        const addressManager = await deployAddressManager(owner);
        token = await deployTkoToken(
            owner,
            addressManager,
            protoBroker.address
        );
        amountMinted = ethers.utils.parseEther("100");
        await token.connect(protoBroker).mint(owner.address, amountMinted);

        const ownerBalance = await token.balanceOf(owner.address);
        expect(ownerBalance).to.be.eq(amountMinted);
    });

    describe("mint()", async () => {
        it("throws when to is equal to the zero address", async () => {
            await expect(
                token.connect(protoBroker).mint(ethers.constants.AddressZero, 1)
            ).to.be.revertedWithCustomError(token, "ErrInvalidAddress");
        });

        it("throws when minter is not the protoBroker", async () => {
            await expect(
                token.connect(owner).mint(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWithCustomError(token, "ErrAccessDenied");
        });

        it("succeeds", async () => {
            const originalBalance = await token.balanceOf(nonOwner.address);

            await token
                .connect(protoBroker)
                .mint(nonOwner.address, amountMinted);

            const postTransferBalance = await token.balanceOf(nonOwner.address);
            expect(postTransferBalance).to.be.eq(
                originalBalance.add(amountMinted)
            );
        });
    });

    describe("burn()", async () => {
        it("throws when to is equal to the zero address", async () => {
            await expect(
                token.connect(protoBroker).burn(ethers.constants.AddressZero, 1)
            ).to.be.revertedWithCustomError(token, "ErrInvalidAddress");
        });

        it("throws when burner is not the protoBroker", async () => {
            await expect(
                token.connect(owner).burn(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWithCustomError(token, "ErrAccessDenied");
        });

        it("throws when account balance is < amount requested to burn", async () => {
            await expect(
                token
                    .connect(protoBroker)
                    .burn(owner.address, amountMinted.add(1))
            ).to.be.revertedWith("ERC20: burn amount exceeds balance");
        });

        it("succeeds", async () => {
            const originalBalance = await token.balanceOf(owner.address);

            await token.connect(protoBroker).burn(owner.address, amountMinted);

            const postTransferBalance = await token.balanceOf(owner.address);
            expect(postTransferBalance).to.be.eq(
                originalBalance.sub(amountMinted)
            );
        });
    });

    describe("transfer()", async () => {
        it("throws when to is equal to the contract address", async () => {
            await expect(
                token.connect(owner).transfer(token.address, 1)
            ).to.be.revertedWithCustomError(token, "ErrInvalidAddress");
        });

        it("throws when transfer is > user's amount", async () => {
            await expect(
                token
                    .connect(owner)
                    .transfer(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
        });

        it("succeeds", async () => {
            const originalBalance = await token.balanceOf(nonOwner.address);

            await token.connect(owner).transfer(nonOwner.address, amountMinted);
            const postTransferBalance = await token.balanceOf(nonOwner.address);
            expect(postTransferBalance).to.be.eq(
                originalBalance.add(amountMinted)
            );
        });
    });
});
