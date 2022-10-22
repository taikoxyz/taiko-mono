// import { expect } from "chai"
import { ethers } from "hardhat"

describe("LibBridgeSend", function () {
    async function deployLibBridgeSendFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        const libSend = await (
            await ethers.getContractFactory("TestLibBridgeSend")
        ).deploy()

        return { owner, nonOwner, libSend }
    }
    it("stub", async function () {
        deployLibBridgeSendFixture()
    })
})
