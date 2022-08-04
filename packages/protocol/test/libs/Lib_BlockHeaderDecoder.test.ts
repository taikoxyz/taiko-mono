// eslint-disable-next-line no-unused-vars
import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("Lib_BlockHeaderDecoder", async function () {
    // eslint-disable-next-line no-unused-vars
    let blockHeaderDecoder: any
    before(async function () {
        blockHeaderDecoder = await (
            await ethers.getContractFactory("TestLibBlockHeaderDecoder")
        ).deploy()
    })
})
