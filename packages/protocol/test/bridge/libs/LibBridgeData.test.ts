import { expect } from "chai"
import { AddressManager } from "../../../typechain"
import { ethers } from "hardhat"
import { TAIKO_BRIDGE_MESSAGE } from "../../constants/messages"

describe("LibBridgeData", function () {
    async function deployLibBridgeDataFixture() {
        const [owner, nonOwner] = await ethers.getSigners()
        // deploy addressManager
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const libData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy()
        return { owner, nonOwner, addressManager, libData }
    }

    describe("LibBridgeData", async function () {
        it("should return properly hashed message", async function () {
            const { owner, nonOwner, libData } =
                await deployLibBridgeDataFixture()
            // dummy struct to test with
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

            const testTypes = [
                "string",
                "tuple(uint256 id, address sender, uint256 srcChainId, uint256 destChainId, address owner, address to, address refundAddress, uint256 depositValue, uint256 callValue, uint256 processingFee, uint256 gasLimit, bytes data, string memo)",
            ]

            const testVar = [TAIKO_BRIDGE_MESSAGE, testMessage]
            const hashed = await libData.hashMessage(testMessage)
            const expectedEncoded = await ethers.utils.defaultAbiCoder.encode(
                testTypes,
                testVar
            )

            const expectedHash = await ethers.utils.keccak256(expectedEncoded)

            expect(expectedHash).to.be.eq(hashed)
        })
    })
})
