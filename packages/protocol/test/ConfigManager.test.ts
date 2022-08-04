import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("ConfigManager", function () {
    let configManager: any
    let testKey: any
    let testName: any

    before(async function () {
        configManager = await (
            await ethers.getContractFactory("ConfigManager")
        ).deploy()
        await configManager.init()
        testKey = ethers.utils.hexlify(ethers.utils.randomBytes(32))
        testName = "test"
    })
    it("should set new value to replace an old value and emit an Updated event.", async function () {
        await expect(configManager.set(testName, testKey)).to.emit(
            configManager,
            "Updated"
        )
    })

    it("should not emit any event if the new value is the same as the old value.", async function () {
        await expect(configManager.set(testName, testKey)).to.not.emit(
            configManager,
            "Updated"
        )
    })

    it("should return an empty byte array for non-set name", async function () {
        const returnValue = await configManager.get("unsetName")
        expect(returnValue).to.equal("0x")
    })

    it("should return the correct key given the previous set name.", async function () {
        expect(await configManager.get(testName)).to.equal(testKey)
    })
})
