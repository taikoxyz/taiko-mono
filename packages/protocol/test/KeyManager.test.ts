import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("KeyManager tests", function () {
    let keyManager: any
    before(async function () {
        keyManager = await (
            await ethers.getContractFactory("KeyManager")
        ).deploy()
        await keyManager.init()
    })
    describe("Testing set and get Key", async function () {
        const testKey = ethers.utils.hexlify(ethers.utils.randomBytes(32))
        const testName = "test"

        it("setKey should not revert & emit event KeySet", async function () {
            await expect(keyManager.setKey(testName, testKey)).to.emit(
                keyManager,
                "KeySet"
            )
        })

        it("getKey with testName should return testKey", async function () {
            expect(await keyManager.getKey(testName)).to.equal(testKey)
        })
    })
})
