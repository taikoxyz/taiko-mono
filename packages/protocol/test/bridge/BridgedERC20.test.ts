import { expect } from "chai"
import { AddressManager, BridgedERC20 } from "../../typechain"
import { ethers } from "hardhat"
import { BigNumber } from "ethers"
import {
    ADDRESS_RESOLVER_DENIED,
    ERC20_BURN_AMOUNT_EXCEEDED,
    ERC20_TRANSFER_AMOUNT_EXCEEDED,
} from "../constants/errors"

const WETH_GOERLI = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6"
const CHAIN_ID_GOERLI = 5
describe("BridgedERC20", function () {
    async function deployUninitializedBridgedERC20Fixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        // Deploying addressManager Contract
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const BridgedERC20Factory = await ethers.getContractFactory(
            "BridgedERC20"
        )

        const erc20: BridgedERC20 = await BridgedERC20Factory.connect(
            owner
        ).deploy()

        return {
            owner,
            nonOwner,
            addressManager,
            erc20,
        }
    }

    async function deployBridgedERC20Fixture() {
        const [owner, tokenVault, nonOwner, accountWithTokens] =
            await ethers.getSigners()

        // Deploying addressManager Contract
        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await addressManager.init()

        const network = await ethers.provider.getNetwork()

        await addressManager.setAddress(
            `${network.chainId}.token_vault`,
            tokenVault.address
        )

        const BridgedERC20Factory = await ethers.getContractFactory(
            "BridgedERC20"
        )

        const erc20: BridgedERC20 = await BridgedERC20Factory.connect(
            owner
        ).deploy()

        await erc20
            .connect(owner)
            .init(
                addressManager.address,
                WETH_GOERLI,
                CHAIN_ID_GOERLI,
                18,
                "SYMB",
                "Name"
            )

        await erc20
            .connect(tokenVault)
            .bridgeMintTo(
                accountWithTokens.address,
                ethers.utils.parseEther("1.0")
            )

        return {
            owner,
            nonOwner,
            addressManager,
            erc20,
            tokenVault,
            accountWithTokens,
        }
    }

    describe("init()", function () {
        it("inits when srctoken is not 0, srcChainId is not 0, srcChainId is not the current blocks chain id, symbol is not 0 length, name is not 0 length", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        CHAIN_ID_GOERLI,
                        18,
                        "SYMB",
                        "Name"
                    )
            ).not.to.be.revertedWith("BE:params")
        })
        it("throws when _srcToken is address 0 ", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        ethers.constants.AddressZero,
                        CHAIN_ID_GOERLI,
                        18,
                        "SYMB",
                        "Name"
                    )
            ).to.be.revertedWith("BE:params")
        })

        it("throws when _srcChainId is 0", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        0,
                        18,
                        "SYMB",
                        "Name"
                    )
            ).to.be.revertedWith("BE:params")
        })

        it("throws when _symbol is 0 length", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        CHAIN_ID_GOERLI,
                        18,
                        "",
                        "Name"
                    )
            ).to.be.revertedWith("BE:params")
        })

        it("throws when _name is 0 length", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        CHAIN_ID_GOERLI,
                        18,
                        "SYMB",
                        ""
                    )
            ).to.be.revertedWith("BE:params")
        })

        it("throws when _srcChainId is equal to block.chainid", async () => {
            const { owner, erc20, addressManager } =
                await deployUninitializedBridgedERC20Fixture()

            const network = await ethers.provider.getNetwork()
            await expect(
                erc20
                    .connect(owner)
                    .init(
                        addressManager.address,
                        WETH_GOERLI,
                        network.chainId,
                        18,
                        "SYMB",
                        "name"
                    )
            ).to.be.revertedWith("BE:params")
        })
    })

    describe("source()", function () {
        it("returns srcToken and srcChainId", async () => {
            const { erc20 } = await deployBridgedERC20Fixture()

            const [srcToken, srcChainId] = await erc20.source()

            expect(srcToken).to.be.eq(WETH_GOERLI)
            expect(srcChainId).to.be.eq(CHAIN_ID_GOERLI)
        })
    })

    describe("bridgeMintTo()", function () {
        it("throws when not called by token_vault", async () => {
            const { owner, erc20 } = await deployBridgedERC20Fixture()
            const amount = BigNumber.from(1)
            await expect(
                erc20.bridgeMintTo(owner.address, amount)
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED)
        })

        it("successfully mintes and emits BridgeMint when called by token_vault, balance inceases for account specified, burns and emits BridgeBurn", async () => {
            const { owner, erc20, tokenVault } =
                await deployBridgedERC20Fixture()
            const amount = BigNumber.from(150)

            const initialBalance = await erc20.balanceOf(owner.address)
            expect(initialBalance).to.be.eq(BigNumber.from(0))

            expect(
                await erc20
                    .connect(tokenVault)
                    .bridgeMintTo(owner.address, amount)
            )
                .to.emit(erc20, "BridgeMint")
                .withArgs(owner.address, amount)
            const newBalance = await erc20.balanceOf(owner.address)
            expect(newBalance).to.be.eq(initialBalance.add(amount))

            expect(
                await erc20
                    .connect(tokenVault)
                    .bridgeBurnFrom(owner.address, amount)
            )
                .to.emit(erc20, "BridgeBurn")
                .withArgs(owner.address, amount)

            const afterBurnBalance = await erc20.balanceOf(owner.address)
            expect(afterBurnBalance).to.be.eq(newBalance.sub(amount))
        })
    })

    describe("bridgeBurnFrom()", function () {
        it("throws when not called by token_vault", async () => {
            const { owner, erc20 } = await deployBridgedERC20Fixture()
            const amount = BigNumber.from(1)
            await expect(
                erc20.bridgeBurnFrom(owner.address, amount)
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED)
        })

        it("can not burn an amount greater than was minted", async () => {
            const { accountWithTokens, erc20, tokenVault } =
                await deployBridgedERC20Fixture()

            const initialBalance = await erc20.balanceOf(
                accountWithTokens.address
            )

            await expect(
                erc20
                    .connect(tokenVault)
                    .bridgeBurnFrom(
                        accountWithTokens.address,
                        initialBalance.add(1)
                    )
            ).to.be.revertedWith(ERC20_BURN_AMOUNT_EXCEEDED)
        })
    })

    describe("transferFrom()", function () {
        it("throws when trying to transfer to itself", async () => {
            const { accountWithTokens, erc20 } =
                await deployBridgedERC20Fixture()

            await expect(
                erc20
                    .connect(accountWithTokens)
                    .transferFrom(accountWithTokens.address, erc20.address, 1)
            ).to.be.revertedWith("BE:to")
        })
    })

    describe("transfer()", function () {
        it("throws when trying to transfer to itself", async () => {
            const { accountWithTokens, erc20 } =
                await deployBridgedERC20Fixture()

            await expect(
                erc20.connect(accountWithTokens).transfer(erc20.address, 1)
            ).to.be.revertedWith("BE:to")
        })

        it("throws when trying to transfer amount greater than holder owns", async () => {
            const { accountWithTokens, owner, erc20 } =
                await deployBridgedERC20Fixture()

            const initialBalance = await erc20.balanceOf(
                accountWithTokens.address
            )

            await expect(
                erc20
                    .connect(accountWithTokens)
                    .transfer(owner.address, initialBalance.add(1))
            ).to.be.revertedWith(ERC20_TRANSFER_AMOUNT_EXCEEDED)
        })
        it("transfers, emits Transfer event, balances are correct after transfer", async () => {
            const { accountWithTokens, owner, erc20 } =
                await deployBridgedERC20Fixture()
            const initialRecipientBalance = await erc20.balanceOf(owner.address)
            const initialAccountWithTokensBalance = await erc20.balanceOf(
                accountWithTokens.address
            )
            const amount = BigNumber.from(100)

            expect(
                await erc20
                    .connect(accountWithTokens)
                    .transfer(owner.address, amount)
            )
                .to.emit(erc20, "Transfer")
                .withArgs(accountWithTokens.address, amount)

            const newRecipientBalance = await erc20.balanceOf(owner.address)
            const newAccountWithTokensBalance = await erc20.balanceOf(
                accountWithTokens.address
            )

            expect(newRecipientBalance).to.be.eq(
                initialRecipientBalance.add(amount)
            )
            expect(newAccountWithTokensBalance).to.be.eq(
                initialAccountWithTokensBalance.sub(amount)
            )
        })
    })
})
