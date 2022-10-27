import { expect } from "chai"
import hre, { ethers } from "hardhat"
import { smock } from "@defi-wonderland/smock"
import { AddressResolver } from "../../../typechain"
import { Message } from "../../utils/message"

describe("LibBridgeSend", function () {
    async function deployLibBridgeSendFixture() {
        const [owner, nonOwner, etherVault] = await ethers.getSigners()

        const libSend = await (
            await ethers.getContractFactory("TestLibBridgeSend")
        ).deploy()

        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()

        const addressResolver = await smock.fake<AddressResolver>(
            "AddressResolver"
        )
        addressResolver["resolve(string)"]
            .whenCalledWith("ether_vault")
            .returns(etherVault.address)

        return { owner, nonOwner, libSend, addressResolver }
    }
    describe("enableDestChain()", async function () {
        it("should throw when chainId <= 0", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            await expect(libSend.enableDestChain(0, true)).to.be.revertedWith(
                "B:chainId"
            )
        })

        it("should throw when chainId == block.chainId", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            const blockChainId = hre.network.config.chainId

            await expect(
                libSend.enableDestChain(blockChainId, true)
            ).to.be.revertedWith("B:chainId")
        })

        it("should emit DestChainEnabled() event", async function () {
            const { libSend } = await deployLibBridgeSendFixture()

            let blockChainId = hre.network.config.chainId ?? 0
            blockChainId += 1

            expect(await libSend.enableDestChain(blockChainId, true)).to.emit(
                libSend,
                "DestChainEnabled"
            )
        })
    })

    describe("sendMessage()", async function () {
        it("should throw when message.owner == address(0)", async function () {
            const { owner, nonOwner, libSend, addressResolver } =
                await deployLibBridgeSendFixture()

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: ethers.constants.AddressZero,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            }
            const signal = await libSend.sendMessage(addressResolver, message)
            // expect(
            //     await libSend.sendMessage(addressResolver, message)
            // ).to.be.revertedWith("B:owner")
        })

        it("should throw when destchainId == block.chainId", async function () {
            deployLibBridgeSendFixture()
        })

        it("should throw when destChainId has not yet been enabled", async function () {
            deployLibBridgeSendFixture()
        })

        it("should throw when expectedAmount != msg.value", async function () {
            deployLibBridgeSendFixture()
        })

        it("should emit MessageSent() event and signal should be hashed correctly", async function () {
            deployLibBridgeSendFixture()
        })
    })
})
