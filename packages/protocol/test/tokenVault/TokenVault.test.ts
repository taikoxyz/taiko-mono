/* eslint-disable camelcase */
import { expect } from "chai";
import {
    AddressManager,
    AddressManager__factory,
    BridgedERC20,
    BridgedERC20__factory,
    TestMessageSender__factory,
    TokenVault,
    TokenVault__factory,
} from "../../typechain";
import { ethers } from "hardhat";
import { BigNumber, BigNumberish } from "ethers";
import { ADDRESS_RESOLVER_DENIED } from "../constants/errors";
import { MockContract, smock } from "@defi-wonderland/smock";

type CanonicalERC20 = {
    chainId: BigNumberish;
    addr: string;
    decimals: BigNumberish;
    symbol: string;
    name: string;
};

const weth: CanonicalERC20 = {
    chainId: 5,
    addr: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    decimals: 18,
    symbol: "WETH",
    name: "Wrapped Ether",
};

describe("TokenVault", function () {
    let owner: any;
    let nonOwner: any;
    let L1TokenVault: MockContract<TokenVault>;
    let tokenVaultAddressManager: AddressManager;
    let destChainTokenVault: TokenVault;
    const defaultProcessingFee = 10;
    const destChainId = 167001;
    let bridgedToken: MockContract<BridgedERC20>;

    before(async function () {
        [owner, nonOwner] = await ethers.getSigners();
    });

    beforeEach(async function () {
        const network = await ethers.provider.getNetwork();
        const addressManagerFactory: AddressManager__factory =
            await ethers.getContractFactory("AddressManager");
        const tokenVaultFactory: TokenVault__factory =
            await ethers.getContractFactory("TokenVault");

        tokenVaultAddressManager = await addressManagerFactory.deploy();
        await tokenVaultAddressManager.init();

        const mockTokenVaultFactory = await smock.mock<TokenVault__factory>(
            "TokenVault"
        );

        L1TokenVault = await mockTokenVaultFactory.connect(owner).deploy();
        await L1TokenVault.init(tokenVaultAddressManager.address);

        destChainTokenVault = await tokenVaultFactory.connect(owner).deploy();
        await destChainTokenVault.init(tokenVaultAddressManager.address);

        const TestMessageSenderFactory: TestMessageSender__factory =
            await ethers.getContractFactory("TestMessageSender");

        const testMessageSender = await TestMessageSenderFactory.deploy();
        const testMessageSender2 = await TestMessageSenderFactory.deploy();

        await tokenVaultAddressManager.setAddress(
            `${network.chainId}.bridge`,
            testMessageSender.address
        );
        await tokenVaultAddressManager.setAddress(
            `${destChainId}.bridge`,
            testMessageSender2.address
        );
        await tokenVaultAddressManager.setAddress(
            `${network.chainId}.token_vault`,
            L1TokenVault.address
        );
        await tokenVaultAddressManager.setAddress(
            `${destChainId}.token_vault`,
            destChainTokenVault.address
        );

        const bridgedTokenFactory = await smock.mock<BridgedERC20__factory>(
            "BridgedERC20"
        );

        bridgedToken = await bridgedTokenFactory.deploy();

        await bridgedToken.init(
            tokenVaultAddressManager.address,
            weth.addr,
            destChainId,
            18,
            weth.symbol,
            weth.name
        );

        await bridgedToken.setVariable("_totalSupply", 1000000);
        await bridgedToken.approve(owner.address, 1000);
        await bridgedToken.setVariable("_balances", { [owner.address]: 10 });
    });

    describe("receiveERC20()", async () => {
        it("throws when named 'bridge' is not the caller", async () => {
            const amount = BigNumber.from(1);

            await expect(
                L1TokenVault.receiveERC20(
                    weth,
                    owner.address,
                    nonOwner.address,
                    amount
                )
            ).to.be.revertedWith(ADDRESS_RESOLVER_DENIED);
        });
    });

    describe("sendEther()", async () => {
        it("throws when msg.value is 0", async () => {
            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    ""
                )
            ).to.be.revertedWith("V:msgValue");
        });

        it("throws when msg.value - processing fee is 0", async () => {
            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    "",
                    {
                        value: defaultProcessingFee,
                    }
                )
            ).to.be.revertedWith("V:msgValue");
        });

        it("throws when msg.value is < processingFee", async () => {
            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    "",
                    {
                        value: defaultProcessingFee - 1,
                    }
                )
            ).to.be.revertedWith("V:msgValue");
        });

        it("throws when to is 0", async () => {
            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    ethers.constants.AddressZero,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    "",
                    {
                        value: defaultProcessingFee - 1,
                    }
                )
            ).to.be.revertedWith("V:to");
        });

        it("succeeds with processingFee", async () => {
            const depositValue = 1000;

            const msgHash =
                "0x3fd54831f488a22b28398de0c567a3b064b937f54f81739ae9bd545967f3abab";

            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    "",
                    {
                        value: depositValue,
                    }
                )
            )
                .to.emit(L1TokenVault, "EtherSent")
                .withArgs(
                    msgHash,
                    owner.address,
                    owner.address,
                    destChainId,
                    depositValue - defaultProcessingFee
                );
        });

        it("succeeds with 0 processingFee", async () => {
            const depositValue = 1000;

            const msgHash =
                "0x3fd54831f488a22b28398de0c567a3b064b937f54f81739ae9bd545967f3abab";

            await expect(
                L1TokenVault.sendEther(
                    destChainId,
                    owner.address,
                    10000,
                    defaultProcessingFee,
                    owner.address,
                    "",
                    {
                        value: depositValue,
                    }
                )
            )
                .to.emit(L1TokenVault, "EtherSent")
                .withArgs(
                    msgHash,
                    owner.address,
                    owner.address,
                    destChainId,
                    depositValue - defaultProcessingFee
                );
        });
    });

    describe("sendERC20()", async () => {
        it("should throw if to == address(0)", async function () {
            await expect(
                L1TokenVault.sendERC20(
                    destChainId,
                    ethers.constants.AddressZero,
                    weth.addr,
                    1,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1,
                    }
                )
            ).to.be.revertedWith("V:to");
        });

        it("should throw if to == destChainId.token_vault", async function () {
            await expect(
                L1TokenVault.sendERC20(
                    destChainId,
                    destChainTokenVault.address,
                    weth.addr,
                    1,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1,
                    }
                )
            ).to.be.revertedWith("V:to");
        });

        it("should throw if token == address(0)", async function () {
            await expect(
                L1TokenVault.sendERC20(
                    destChainId,
                    nonOwner.address,
                    ethers.constants.AddressZero,
                    1,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1,
                    }
                )
            ).to.be.revertedWith("V:token");
        });

        it("should throw if amount <= 0", async function () {
            await expect(
                L1TokenVault.sendERC20(
                    destChainId,
                    nonOwner.address,
                    weth.addr,
                    0,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1,
                    }
                )
            ).to.be.revertedWith("V:amount");
        });

        it("should throw if isBridgedToken, and canonicalToken.addr == address(0)", async function () {
            await L1TokenVault.setVariable("isBridgedToken", {
                [bridgedToken.address]: true,
            });
            // don't need to manually set bridgedToCanonical since default value is addressZero

            await expect(
                L1TokenVault.connect(owner).sendERC20(
                    destChainId,
                    nonOwner.address,
                    bridgedToken.address,
                    1,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1,
                    }
                )
            ).to.be.revertedWith("V:canonicalToken");
        });

        it("should pass and emit ERC20Sent Event", async function () {
            await L1TokenVault.setVariable("isBridgedToken", {
                [bridgedToken.address]: true,
            });

            await L1TokenVault.setVariable("bridgedToCanonical", {
                [bridgedToken.address]: weth,
            });

            await expect(
                L1TokenVault.connect(owner).sendERC20(
                    destChainId,
                    nonOwner.address,
                    bridgedToken.address,
                    1,
                    20000000,
                    1000,
                    owner.address,
                    "",
                    {
                        value: 1000,
                    }
                )
            ).to.emit(L1TokenVault, "ERC20Sent");
        });
    });
});
