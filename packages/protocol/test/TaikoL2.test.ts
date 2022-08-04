import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("TaikoL2 tests", function () {
    let taikoL2: any
    let receiverWallet: any

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    before(async function () {
        // Deploying receiverWallet to test unwrap and wrap Ether, init with 150.0 Ether
        const receiverWallet = await ethers.Wallet.createRandom().address
        const [owner] = await ethers.getSigners()
        await owner.sendTransaction({
            to: receiverWallet,
            value: ethers.utils.parseEther("150.0"),
        })

        // Deploying addressManager Contract
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        // Deploying TaikoL2 Contract linked with LibTxList (throws error otherwise)
        const txListLib = await (
            await ethers.getContractFactory("LibTxList")
        ).deploy()

        const taikoL2Factory = await ethers.getContractFactory("TaikoL2", {
            libraries: {
                LibTxList: txListLib.address,
            },
        })
        taikoL2 = await taikoL2Factory.deploy()
        await taikoL2.init(addressManager.address)
    })

    describe("Testing wrap/unwrapEther", async function () {
        describe("testing unwrapEther", async function () {
            it("should revert if amount to unwrap == 0", async function () {
                await expect(taikoL2.unwrapEther(receiverWallet, 0)).to.reverted
            })

            // it("should not revert", async function () {
            //     await taikoL2.unwrapEther(receiverWallet, 10)
            //     expect(
            //         await ethers.provider.getBalance(taikoL2.address)
            //     ).to.equal(ethers.utils.parseEther("10.0"))
            // })
        })

        // describe("testing wrapEther", async function () {
        //     it("should not revert", async function () {
        //         await taikoL2.wrapEther(receiverWallet, { value: 10.0 })
        //     })
        // })
    })

    describe("Testing anchor() function", async function () {
        it("should revert since anchorHeight == 0", async function () {
            const randomHash = randomBytes32()
            await expect(taikoL2.anchor(0, randomHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should revert since anchorHash == 0x0", async function () {
            const zeroHash = ethers.constants.HashZero
            await expect(taikoL2.anchor(10, zeroHash)).to.be.revertedWith(
                "invalid anchor"
            )
        })
        it("should not revert, and should emit an Anchored event", async function () {
            const randomHash = randomBytes32()
            await expect(taikoL2.anchor(1, randomHash)).to.emit(
                taikoL2,
                "Anchored"
            )
        })
    })
})
