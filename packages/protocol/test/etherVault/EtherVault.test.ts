import { expect } from "chai";
import { AddressManager, EtherVault } from "../../typechain";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import deployAddressManager from "../utils/addressManager";

describe("EtherVault", function () {
    let owner: any;
    let nonOwner: any;
    let authorized: any;
    let notAuthorized: any;
    let etherVault: EtherVault;

    before(async function () {
        [owner, nonOwner, authorized, notAuthorized] =
            await ethers.getSigners();
    });

    beforeEach(async function () {
        const addressManager: AddressManager = await deployAddressManager(
            owner
        );

        etherVault = await (await ethers.getContractFactory("EtherVault"))
            .connect(owner)
            .deploy();
        await etherVault.init(addressManager.address);

        await etherVault.connect(owner).authorize(authorized.address, true);

        const isAuthorized = await etherVault.isAuthorized(authorized.address);
        expect(isAuthorized).to.be.eq(true);

        await authorized.sendTransaction({
            to: etherVault.address,
            value: ethers.utils.parseEther("1.0"),
        });

        expect(await ethers.provider.getBalance(etherVault.address)).to.be.eq(
            ethers.utils.parseEther("1.0")
        );
    });

    describe("receive()", async function () {
        it("throws if not authorized and balance > 0", async () => {
            const balance = await ethers.provider.getBalance(
                etherVault.address
            );
            expect(balance).to.not.be.eq(BigNumber.from(0));
            await expect(
                notAuthorized.sendTransaction({
                    to: etherVault.address,
                    value: ethers.utils.parseEther("1.0"),
                })
            ).to.be.revertedWith("EV:denied");
        });

        it("receives if authorized and balance > 0", async () => {
            const amount = BigNumber.from(1);
            const originalBalance = await ethers.provider.getBalance(
                etherVault.address
            );
            expect(originalBalance).to.not.be.eq(BigNumber.from(0));
            await authorized.sendTransaction({
                to: etherVault.address,
                value: amount,
            });
            const newBalance = await ethers.provider.getBalance(
                etherVault.address
            );
            expect(newBalance).to.be.eq(amount.add(originalBalance));
        });
    });

    describe("releaseEther()", async function () {
        it("throws if not enough ether to send", async () => {
            const balance = await ethers.provider.getBalance(
                etherVault.address
            );
            const additionalAmount = 1;
            await expect(
                etherVault
                    .connect(authorized)
                    ["releaseEther(uint256)"](balance.add(additionalAmount))
            ).to.be.revertedWith("ETH transfer failed");
        });

        it("throws if not authorized", async () => {
            await expect(
                etherVault.connect(notAuthorized)["releaseEther(uint256)"](1)
            ).to.be.revertedWith("EV:denied");
        });

        it("sends ether to caller", async () => {
            const amount = 100000;
            const originalBalance = await ethers.provider.getBalance(
                authorized.address
            );

            const tx = await etherVault
                .connect(authorized)
                ["releaseEther(uint256)"](amount);
            const receipt = await tx.wait();
            const gasUsed = receipt.cumulativeGasUsed.mul(
                receipt.effectiveGasPrice
            );
            const newBalance = await ethers.provider.getBalance(
                authorized.address
            );

            expect(newBalance).to.be.eq(
                originalBalance.add(amount).sub(gasUsed)
            );
        });

        it("emits EtherReleased event upon success", async () => {
            const amount = 69;

            await expect(
                etherVault.connect(authorized)["releaseEther(uint256)"](amount)
            )
                .to.emit(etherVault, "EtherReleased")
                .withArgs(authorized.address, amount);
        });
    });

    describe("authorize()", async function () {
        it("throws when not called by owner", async () => {
            await expect(
                etherVault
                    .connect(nonOwner)
                    .authorize(notAuthorized.address, true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("throws when address is 0", async () => {
            await expect(
                etherVault
                    .connect(owner)
                    .authorize(ethers.constants.AddressZero, true)
            ).to.be.revertedWith("EV:param");
        });

        it("throws when authorized state is the same as input", async () => {
            await expect(
                etherVault.connect(owner).authorize(authorized.address, true)
            ).to.be.revertedWith("EV:param");
        });

        it("emits Authorized event upon success", async () => {
            await expect(
                etherVault.connect(owner).authorize(notAuthorized.address, true)
            )
                .to.emit(etherVault, "Authorized")
                .withArgs(notAuthorized.address, true);
        });

        it("address is authorized in mapping, can de-authorize", async () => {
            await etherVault
                .connect(owner)
                .authorize(notAuthorized.address, true);

            let isAuthorized = await etherVault.isAuthorized(
                notAuthorized.address
            );
            expect(isAuthorized).to.be.eq(true);

            await etherVault
                .connect(owner)
                .authorize(notAuthorized.address, false);

            isAuthorized = await etherVault.isAuthorized(notAuthorized.address);
            expect(isAuthorized).to.be.eq(false);
        });
    });
});
