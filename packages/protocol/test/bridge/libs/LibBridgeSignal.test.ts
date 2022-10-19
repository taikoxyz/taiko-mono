// import { expect } from "chai"
import { AddressManager } from "../../../typechain"
import { ethers } from "hardhat"
// import { TAIKO_BRIDGE_MESSAGE } from "../../constants/messages"

describe("LibBridgeData", function () {
    async function deployLibBridgeSignalFixture() {
        const [owner, nonOwner] = await ethers.getSigners()
        // deploy addressManager
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const libSignal = await (
            await ethers.getContractFactory("TestLibBridgeSignal")
        ).deploy()
        return { owner, nonOwner, addressManager, libSignal }
    }

    describe("LibBridgeSignal", async function () {
        describe("sendSignal()", async function () {
            it("stub", async function () {
                const { owner, nonOwner, addressManager, libSignal } =
                    await deployLibBridgeSignalFixture()
                console.log(owner, nonOwner, addressManager, libSignal)
            })
            //     it.only("throws when sender is zero address", async function () {
            //         const { owner, nonOwner, bridge, enabledDestChainId } =
            //             await deployBridgeFixture()
            //         const message: Message = {
            //             id: 1,
            //             sender: owner.address,
            //             srcChainId: 1,
            //             destChainId: enabledDestChainId,
            //             owner: owner.address,
            //             to: nonOwner.address,
            //             refundAddress: owner.address,
            //             depositValue: 1,
            //             callValue: 1,
            //             processingFee: 1,
            //             gasLimit: 100,
            //             data: ethers.constants.HashZero,
            //             memo: "",
            //         }
            //         const expectedAmount =
            //             message.depositValue + message.callValue + message.processingFee
            //         const signal = await bridge.sendMessage(message, {
            //             value: expectedAmount,
            //         })
            //         await signal.wait()
            //         expect(
            //             await bridge
            //                 .connect(ethers.constants.AddressZero)
            //                 .sendSignal(signal)
            //         ).to.be.revertedWith("B:sender")
            //     })
        })
    })
})
