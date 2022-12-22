import { expect } from "chai"
import { ethers } from "hardhat"
import { TestLibBridgeData, TestLibBridgeSignal } from "../../../typechain"
import { Message } from "../../utils/message"

describe("LibBridgeSignal", function () {
    let owner: any
    let nonOwner: any
    let testMessage: Message
    let libData: TestLibBridgeData
    let libSignal: TestLibBridgeSignal

    before(async function () {
        ;[owner, nonOwner] = await ethers.getSigners()

        testMessage = {
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
    })

    beforeEach(async function () {
        libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()

        libSignal = await (
            await ethers.getContractFactory("TestLibBridgeSignal")
        ).deploy()
    })

    describe("sendSignal()", async function () {
        it("throws when sender is zero address", async function () {
            const signal = await libData.hashMessage(testMessage)

            await expect(
                libSignal.sendSignal(ethers.constants.AddressZero, signal)
            ).to.revertedWith("B:sender")
        })

        it("throws when signal is zero", async function () {
            await expect(
                libSignal.sendSignal(owner.address, ethers.constants.HashZero)
            ).to.be.revertedWith("B:signal")
        })
    })

    describe("isSignalSent()", async function () {
        it("properly sent signal should change storage value", async function () {
            const signal = await libData.hashMessage(testMessage)

            await libSignal.sendSignal(owner.address, signal)

            expect(await libSignal.isSignalSent(owner.address, signal)).to.eq(
                true
            )
        })
    })
})
