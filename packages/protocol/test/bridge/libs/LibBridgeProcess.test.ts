import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import {
    getMessageStatusSlot,
    Message,
    MessageStatus,
} from "../../utils/message";
import {
    AddressManager,
    EtherVault,
    TestLibBridgeData,
    TestLibBridgeProcess,
} from "../../../typechain";

// TODO(roger): we should deprecate these test and test Bridge.sol
// as a whole.
describe("LibBridgeProcess", async function () {
    let owner: any;
    let nonOwner: any;
    let etherVaultOwner: any;
    let addressManager: AddressManager;
    let etherVault: EtherVault;
    let libProcessLink;
    let libProcess: TestLibBridgeProcess;
    let testTaikoData: TestLibBridgeData;
    const srcChainId = 1;
    const blockChainId = hre.network.config.chainId ?? 0;

    before(async function () {
        [owner, nonOwner, etherVaultOwner] = await ethers.getSigners();
    });

    beforeEach(async function () {
        addressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        etherVault = await (await ethers.getContractFactory("EtherVault"))
            .connect(etherVaultOwner)
            .deploy();

        await etherVault.deployed();

        await etherVault.init(addressManager.address);

        await etherVault
            .connect(etherVaultOwner)
            .authorize(owner.address, true);
        const blockChainId = hre.network.config.chainId ?? 0;
        await addressManager.setAddress(
            `${blockChainId}.ether_vault`,
            etherVault.address
        );
        // Sends initial value of 10 ether to EtherVault for releaseEther calls
        await owner.sendTransaction({
            to: etherVault.address,
            value: ethers.utils.parseEther("10.0"),
        });

        libProcessLink = await (
            await ethers.getContractFactory("LibBridgeProcess")
        )
            .connect(owner)
            .deploy();
        await libProcessLink.deployed();

        libProcess = await (
            await ethers.getContractFactory("TestLibBridgeProcess", {
                libraries: {
                    LibBridgeProcess: libProcessLink.address,
                },
            })
        )
            .connect(owner)
            .deploy();

        await libProcess.init(addressManager.address);

        testTaikoData = await (
            await ethers.getContractFactory("TestLibBridgeData")
        ).deploy();

        await etherVault
            .connect(etherVaultOwner)
            .authorize(libProcess.address, true);
    });

    describe("processMessage()", async function () {
        it("should throw if gaslimit == 0 & msg.sender != message.owner", async function () {
            const message: Message = {
                id: 1,
                sender: nonOwner.address,
                srcChainId: srcChainId,
                destChainId: blockChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: nonOwner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };
            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:forbidden");
        });

        it("should throw if message.destChain != block.chainId", async function () {
            const badBlockChainId = blockChainId + 1;
            const message: Message = {
                id: 1,
                sender: nonOwner.address,
                srcChainId: srcChainId,
                destChainId: badBlockChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: nonOwner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100000000,
                data: ethers.constants.HashZero,
                memo: "",
            };
            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:destChainId");
        });

        it("should throw if message's status is not NEW", async function () {
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: blockChainId,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100000000,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const signal = await testTaikoData.hashMessage(message);

            await helpers.setStorageAt(
                libProcess.address,
                await getMessageStatusSlot(hre, signal),
                MessageStatus.RETRIABLE
            );

            await expect(
                libProcess.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:status");
        });
        // Remaining test cases require integration, will be covered in Bridge.test.ts
    });
});
