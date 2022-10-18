import { expect } from "chai"
import { AddressManager } from "../../typechain"
import { ethers } from "hardhat"

describe("AddressManager", function () {
    async function deployAddressManagerFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        // Deploying addressManager Contract
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        return {
            owner,
            nonOwner,
            addressManager,
        }
    }

    describe("setAddress()", async () => {
        it("throws when non-owner calls", async () => {
            const { nonOwner, addressManager } =
                await deployAddressManagerFixture()

            const name = "fakename"
            await expect(
                addressManager
                    .connect(nonOwner)
                    .setAddress(name, nonOwner.address)
            ).to.be.revertedWith("")
        })

        it("emits setAddress event", async () => {
            const { owner, nonOwner, addressManager } =
                await deployAddressManagerFixture()

            const name = "fakename"
            await expect(
                addressManager.connect(owner).setAddress(name, nonOwner.address)
            )
                .to.emit(addressManager, "AddressSet")
                .withArgs(name, nonOwner.address, ethers.constants.AddressZero)

            await expect(
                addressManager.connect(owner).setAddress(name, owner.address)
            )
                .to.emit(addressManager, "AddressSet")
                .withArgs(name, owner.address, nonOwner.address)

            expect(await addressManager.getAddress(name)).to.be.eq(
                owner.address
            )
        })
    })
})
