import { expect } from "chai";
import { AddressManager } from "../../typechain";
import { ethers } from "hardhat";
import deployAddressManager from "../utils/addressManager";

describe("AddressManager", function () {
    let owner: any;
    let nonOwner: any;
    let addressManager: AddressManager;

    before(async function () {
        [owner, nonOwner] = await ethers.getSigners();
    });

    beforeEach(async function () {
        addressManager = await deployAddressManager(owner);
    });

    describe("setAddress()", async () => {
        it("throws when non-owner calls", async () => {
            const name = "fakename";
            await expect(
                addressManager
                    .connect(nonOwner)
                    .setAddress(name, nonOwner.address)
            ).to.be.revertedWith("");
        });

        it("emits setAddress event", async () => {
            const name = "fakename";
            await expect(
                addressManager.connect(owner).setAddress(name, nonOwner.address)
            )
                .to.emit(addressManager, "AddressSet")
                .withArgs(name, nonOwner.address, ethers.constants.AddressZero);

            await expect(
                addressManager.connect(owner).setAddress(name, owner.address)
            )
                .to.emit(addressManager, "AddressSet")
                .withArgs(name, owner.address, nonOwner.address);

            expect(await addressManager.getAddress(name)).to.be.eq(
                owner.address
            );
        });
    });
});
