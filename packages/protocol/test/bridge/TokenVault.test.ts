import { expect } from "chai"
import { AddressManager, TokenVault } from "../../typechain"
import { ethers } from "hardhat"
import { BigNumber, BigNumberish } from "ethers"
import { ADDRESS_RESOLVER_DENIED } from "../constants/errors"

type CanonicalERC20 = {
    chainId: BigNumberish
    addr: string
    decimals: BigNumberish
    symbol: string
    name: string
}

const weth: CanonicalERC20 = {
    chainId: 5,
    addr: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    decimals: 18,
    symbol: "WETH",
    name: "Wrapped Ether",
}

describe("TokenVault", function () {
    async function deployTokenVaultFixture() {
        const [owner, nonOwner] = await ethers.getSigners()

        // Deploying addressManager Contract
        const tokenVaultAddressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy()
        await tokenVaultAddressManager.init()

        const TokenVaultFactory = await ethers.getContractFactory("TokenVault")

        const tokenVault: TokenVault = await TokenVaultFactory.connect(
            owner
        ).deploy()

        await tokenVault.init(tokenVaultAddressManager.address)

        const network = await ethers.provider.getNetwork()

        const TestMessageSenderFactory = await ethers.getContractFactory(
            "TestMessageSender"
        )

        const testMessageSender = await TestMessageSenderFactory.deploy()

        await tokenVaultAddressManager.setAddress(
            `${network.chainId}.bridge`,
            testMessageSender.address
        )
        return {
            owner,
            nonOwner,
            tokenVault,
            tokenVaultAddressManager,
        }
    }

    describe("receiveERC20()", async () => {
        it("throws when named 'bridge' is not the caller", async () => {
            const { owner, nonOwner, tokenVault } =
                await deployTokenVaultFixture()
            const amount = BigNumber.from(1)

            await expect(
                tokenVault.receiveERC20(
                    weth,
                    owner.address,
                    nonOwner.address,
                    amount
                )
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED)
        })
    })

    describe("sendEther()", async () => {
        it("throws when msg.value is 0", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 10

            await expect(
                tokenVault.sendEther(
                    167001,
                    owner.address,
                    10000,
                    processingFee,
                    owner.address,
                    ""
                )
            ).to.be.revertedWith("V:msgValue")
        })

        it("throws when msg.value - processing fee is 0", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 10

            await expect(
                tokenVault.sendEther(
                    167001,
                    owner.address,
                    10000,
                    processingFee,
                    owner.address,
                    "",
                    {
                        value: processingFee,
                    }
                )
            ).to.be.revertedWith("V:msgValue")
        })

        it("throws when msg.value is < processingFee", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 10

            await expect(
                tokenVault.sendEther(
                    167001,
                    owner.address,
                    10000,
                    processingFee,
                    owner.address,
                    "",
                    {
                        value: processingFee - 1,
                    }
                )
            ).to.be.revertedWith("V:msgValue")
        })

        it("throws when to is 0", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 10

            await expect(
                tokenVault.sendEther(
                    167001,
                    ethers.constants.AddressZero,
                    10000,
                    processingFee,
                    owner.address,
                    "",
                    {
                        value: processingFee - 1,
                    }
                )
            ).to.be.revertedWith("V:to")
        })

        it("succeeds with processingFee", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 10
            const depositValue = 1000
            const destChainId = 167001

            const testSignal =
                "0x3fd54831f488a22b28398de0c567a3b064b937f54f81739ae9bd545967f3abab"

            await expect(
                tokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    processingFee,
                    owner.address,
                    "",
                    {
                        value: depositValue,
                    }
                )
            )
                .to.emit(tokenVault, "EtherSent")
                .withArgs(
                    owner.address,
                    destChainId,
                    depositValue - processingFee,
                    testSignal
                )
        })

        it("succeeds with 0 processingFee", async () => {
            const { owner, tokenVault } = await deployTokenVaultFixture()

            const processingFee = 0
            const depositValue = 1000
            const destChainId = 167001

            const testSignal =
                "0x3fd54831f488a22b28398de0c567a3b064b937f54f81739ae9bd545967f3abab"

            await expect(
                tokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    processingFee,
                    owner.address,
                    "",
                    {
                        value: depositValue,
                    }
                )
            )
                .to.emit(tokenVault, "EtherSent")
                .withArgs(
                    owner.address,
                    destChainId,
                    depositValue - processingFee,
                    testSignal
                )
        })
    })
})
