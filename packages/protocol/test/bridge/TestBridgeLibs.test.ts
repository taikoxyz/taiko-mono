// import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("Test Bridge Libs", function () {
    let addressManager: any
    let bridge: any
    // let testMessage: any
    // let libData: any

    before(async function () {
        // deploy addressManager
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // deploy Libraries needed to link to Bridge
        const libTrie = await (
            await ethers.getContractFactory("LibTrieProof")
        ).deploy()

        const libProcess = await (
            await ethers.getContractFactory("LibBridgeProcess", {
                libraries: {
                    LibTrieProof: libTrie.address,
                },
            })
        ).deploy()

        const libRetry = await (
            await ethers.getContractFactory("LibBridgeRetry")
        ).deploy()

        // deploying Bridge
        bridge = await (
            await ethers.getContractFactory("Bridge", {
                libraries: {
                    LibBridgeProcess: libProcess.address,
                    LibBridgeRetry: libRetry.address,
                    LibTrieProof: libTrie.address,
                },
            })
        ).deploy()
        await bridge.init(addressManager.address)
    })

    // describe("LibBridgeData", async function () {
    //     before(async function () {
    //         libData = await (
    //             await ethers.getContractFactory("LibBridgeData")
    //         ).deploy()
    //     })

    //     it("should return properly hashed message", async function () {
    //         // await expect()
    //     })
    // })
})
