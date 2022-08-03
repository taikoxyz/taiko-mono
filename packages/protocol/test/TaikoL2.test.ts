import { expect } from "chai"
// import * as log from "../tasks/log"
const hre = require("hardhat")
const ethers = hre.ethers
// const EBN = ethers.BigNumber

describe("TaikoL2 tests", function () {
    let taikoL2: any

    before(async function () {
        taikoL2 = await (await ethers.getContractFactory("TaikoL2")).deploy()
    })

    it("temporary", async function () {
        expect(await taikoL2.anchor(0, 0)).to.reverted
    })
})
