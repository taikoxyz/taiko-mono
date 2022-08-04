import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("ConfigManager tests", function () {
    let configManager: any
    before(async function () {
        configManager = await (
            await ethers.getContractFactory("ConfigManager")
        ).deploy()
        await configManager.init()
    })
    describe("Testing set and get Key", async function () {
        const testKey = ethers.utils.hexlify(ethers.utils.randomBytes(32))
        const testName = "test"

        it("setKey should not revert & emit event KeySet", async function () {
            await expect(configManager.set(testName, testKey)).to.emit(
                configManager,
                "Updated"
            )
        })

        it("getKey with testName should return testKey", async function () {
            expect(await configManager.get(testName)).to.equal(testKey)
        })
    })
})
