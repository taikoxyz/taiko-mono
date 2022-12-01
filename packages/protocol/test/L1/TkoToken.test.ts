import { expect } from "chai"
import { AddressManager, TkoToken } from "../../typechain"
import { ethers } from "hardhat"
import {
    ADDRESS_RESOLVER_DENIED,
    ERC20_BURN_AMOUNT_EXCEEDED,
    ERC20_TRANSFER_AMOUNT_EXCEEDED,
} from "../constants/errors"

describe("TokenVault", function () {
    async function deployTkoTokenFixture() {
        const [owner, nonOwner, protoBroker] = await ethers.getSigners()

        // Deploying addressManager Contract
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const TkoTokenFactory = await ethers.getContractFactory("TkoToken")

        const token: TkoToken = await TkoTokenFactory.connect(owner).deploy()

        await token.init(addressManager.address)

        const { chainId } = await ethers.provider.getNetwork()

        await addressManager.setAddress(
            `${chainId}.proto_broker`,
            protoBroker.address
        )
        const amountMinted = ethers.utils.parseEther("100")
        await token.connect(protoBroker).mint(owner.address, amountMinted)

        const ownerBalance = await token.balanceOf(owner.address)
        expect(ownerBalance).to.be.eq(amountMinted)

        return {
            owner,
            nonOwner,
            token,
            addressManager,
            amountMinted,
            protoBroker,
        }
    }

    describe("mint()", async () => {
        it("throws when to is equal to the zero address", async () => {
            const { token, protoBroker } = await deployTkoTokenFixture()

            await expect(
                token.connect(protoBroker).mint(ethers.constants.AddressZero, 1)
            ).to.be.revertedWith("TKO:account")
        })

        it("throws when minter is not the protoBroker", async () => {
            const { owner, token, amountMinted, nonOwner } =
                await deployTkoTokenFixture()

            await expect(
                token.connect(owner).mint(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED)
        })

        it("succeeds", async () => {
            const { token, amountMinted, nonOwner, protoBroker } =
                await deployTkoTokenFixture()

            const originalBalance = await token.balanceOf(nonOwner.address)

            await token
                .connect(protoBroker)
                .mint(nonOwner.address, amountMinted)

            const postTransferBalance = await token.balanceOf(nonOwner.address)
            expect(postTransferBalance).to.be.eq(
                originalBalance.add(amountMinted)
            )
        })
    })

    describe("burn()", async () => {
        it("throws when to is equal to the zero address", async () => {
            const { token, protoBroker } = await deployTkoTokenFixture()

            await expect(
                token.connect(protoBroker).burn(ethers.constants.AddressZero, 1)
            ).to.be.revertedWith("TKO:account")
        })

        it("throws when burner is not the protoBroker", async () => {
            const { owner, token, amountMinted, nonOwner } =
                await deployTkoTokenFixture()

            await expect(
                token.connect(owner).burn(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED)
        })

        it("throws when account balance is < amount requested to burn", async () => {
            const { owner, protoBroker, token, amountMinted } =
                await deployTkoTokenFixture()

            await expect(
                token
                    .connect(protoBroker)
                    .burn(owner.address, amountMinted.add(1))
            ).to.be.revertedWith(ERC20_BURN_AMOUNT_EXCEEDED)
        })

        it("succeeds", async () => {
            const { token, amountMinted, owner, protoBroker } =
                await deployTkoTokenFixture()

            const originalBalance = await token.balanceOf(owner.address)

            await token.connect(protoBroker).burn(owner.address, amountMinted)

            const postTransferBalance = await token.balanceOf(owner.address)
            expect(postTransferBalance).to.be.eq(
                originalBalance.sub(amountMinted)
            )
        })
    })

    describe("transfer()", async () => {
        it("throws when to is equal to the contract address", async () => {
            const { owner, token } = await deployTkoTokenFixture()

            await expect(
                token.connect(owner).transfer(token.address, 1)
            ).to.be.revertedWith("TKO:to")
        })

        it("throws when transfer is > user's amount", async () => {
            const { owner, token, amountMinted, nonOwner } =
                await deployTkoTokenFixture()

            await expect(
                token
                    .connect(owner)
                    .transfer(nonOwner.address, amountMinted.add(1))
            ).to.be.revertedWith(ERC20_TRANSFER_AMOUNT_EXCEEDED)
        })

        it("succeeds", async () => {
            const { owner, token, amountMinted, nonOwner } =
                await deployTkoTokenFixture()

            const originalBalance = await token.balanceOf(nonOwner.address)

            await token.connect(owner).transfer(nonOwner.address, amountMinted)
            const postTransferBalance = await token.balanceOf(nonOwner.address)
            expect(postTransferBalance).to.be.eq(
                originalBalance.add(amountMinted)
            )
        })
    })
})
