import { expect } from "chai"
import { ethers } from "hardhat"
// import { TAIKO_BRIDGE_MESSAGE } from "../../constants/messages"

describe("LibBridgeSignal", function () {
    async function deployLibBridgeSignalFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const libSignal = await (
            await ethers.getContractFactory("TestLibBridgeSignal")
        ).deploy()

        const testMessage = {
            id: 1,
            sender: owner.address,
            srcChainId: 1,
            destChainId: 2,
            owner: owner.address,
            to: nonOwner.address,
            refundAddress: owner.address,
            depositValue: 0,
            callValue: 0,
            processingFee: 0,
            gasLimit: 0,
            data: ethers.constants.HashZero,
            memo: "",
        }

        return { owner, nonOwner, libSignal, testMessage }
    }
    async function deployLibBridgeDataFixture() {
        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()
        return { libData }
    }

    describe("LibBridgeSignal", async function () {
        describe("sendSignal()", async function () {
            it("throws when sender is zero address", async function () {
                const { libSignal, testMessage } =
                    await deployLibBridgeSignalFixture()
                const { libData } = await deployLibBridgeDataFixture()
                const signal = await libData.hashMessage(testMessage)
                await expect(
                    libSignal.sendSignal(ethers.constants.AddressZero, signal)
                ).to.revertedWith("B:sender")
            })

            // it("throws when signal is zero", async function () {
            //     const { owner, libSignal } =
            //         await deployLibBridgeSignalFixture()
            //     await expect(
            //         libSignal.sendSignal(
            //             owner.address,
            //             ethers.utils.hexlify(ethers.constants.Zero)
            //         )
            //     ).to.be.revertedWith("B:signal")
            // })
        })
    })
})
