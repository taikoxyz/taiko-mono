import { expect } from "chai"
const hre = require("hardhat")
const ethers = hre.ethers

describe("TaikoL2", function () {
    let taikoL2: any
    let WETHToken: any

    function randomBytes32() {
        return ethers.utils.hexlify(ethers.utils.randomBytes(32))
    }

    before(async function () {
        // Deploying receiverWallet to test unwrap and wrap Ether, init with 150.0 Ether
        const [owner] = await ethers.getSigners()

        // deploy simple ERC20 token to test with
        WETHToken = await (
            await ethers.getContractFactory("WETHToken")
        ).deploy()
        await WETHToken.init()

        // Deploying addressManager Contract
        const addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()
        addressManager.setAddress("WETH", WETHToken.address)

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

        // Sending ether to taikoL2 contract to test with
        await owner.sendTransaction({
            to: taikoL2.address,
            value: ethers.utils.parseEther("150.0"),
        })
    })

    describe("Testing wrap/unwrapEther", async function () {
        describe("unwrapEther", async function () {
            it("balance at receiverWallet should equal to the amount of ether unwrapped at taikoL2", async function () {
                const receiverWallet = await ethers.Wallet.createRandom()
                    .address
                const signers = await ethers.getSigners()
                const amount = "100"

                await WETHToken.mint(signers[0].address, amount)
                await WETHToken.approve(taikoL2.address, amount)

                await taikoL2.unwrapEther(receiverWallet, amount)
                expect(
                    await ethers.provider.getBalance(receiverWallet)
                ).to.equal(amount)
            })
        })

        describe("wrapEther", async function () {
            it("balance of receiverWallet at WETHToken contract should equal amount of ether wrapped at taikoL2", async function () {
                const receiverWallet = await ethers.Wallet.createRandom()
                    .address
                const amount = "100"
                const wrapAmount = "10"

                await WETHToken.mint(taikoL2.address, amount)
                await taikoL2.wrapEther(receiverWallet, { value: wrapAmount })
                const balance = await WETHToken.balanceOf(receiverWallet)
                expect(balance.toString()).to.equal(wrapAmount)
            })
        })
    })

    describe("Testing anchor", async function () {
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
