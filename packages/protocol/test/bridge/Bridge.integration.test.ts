import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers as ethersLib } from "ethers";
import hre, { ethers } from "hardhat";
import {
    AddressManager,
    Bridge,
    SignalService,
    TestBadReceiver,
    TestXchainSync,
} from "../../typechain";
import deployAddressManager from "../utils/addressManager";
import {
    deployBridge,
    processMessage,
    sendAndProcessMessage,
    sendMessage,
} from "../utils/bridge";
import { txShouldRevertWithCustomError } from "../utils/errors";
// import { randomBytes32 } from "../utils/bytes";
import { Message } from "../utils/message";
import {
    getDefaultL2Signer,
    getL1Provider,
    getL2Provider,
} from "../utils/provider";
import { Block, getBlockHeader } from "../utils/rpc";
import { deploySignalService, getSignalProof } from "../utils/signal";

describe("integrationbridge:Bridge", function () {
    let owner: SignerWithAddress;
    let l1Provider: ethersLib.providers.JsonRpcProvider;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l2Signer: ethersLib.Signer;
    let srcChainId: number;
    let enabledDestChainId: number;
    let l2NonOwner: ethersLib.Signer;
    let l1SignalService: SignalService;
    let l2SignalService: SignalService;
    let l1Bridge: Bridge;
    let l2Bridge: Bridge;
    let m: Message;
    let l1XchainSync: TestXchainSync;
    let l2XchainSync: TestXchainSync;

    beforeEach(async () => {
        [owner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        srcChainId = chainId;

        l1Provider = getL1Provider();

        // seondary node to deploy L2 on
        l2Provider = getL2Provider();

        l2Signer = await getDefaultL2Signer();

        l2NonOwner = await l2Provider.getSigner(
            await ethers.Wallet.createRandom().getAddress()
        );

        const l2Network = await l2Provider.getNetwork();

        enabledDestChainId = l2Network.chainId;

        const addressManager: AddressManager = await deployAddressManager(
            owner
        );

        const l2AddressManager: AddressManager = await deployAddressManager(
            l2Signer
        );

        ({ signalService: l1SignalService } = await deploySignalService(
            owner,
            addressManager,
            srcChainId
        ));

        ({ signalService: l2SignalService } = await deploySignalService(
            l2Signer,
            l2AddressManager,
            enabledDestChainId
        ));

        await addressManager.setAddress(
            `${enabledDestChainId}.signal_service`,
            l2SignalService.address
        );

        await l2AddressManager.setAddress(
            `${srcChainId}.signal_service`,
            l1SignalService.address
        );

        ({ bridge: l1Bridge } = await deployBridge(
            owner,
            addressManager,
            srcChainId
        ));

        ({ bridge: l2Bridge } = await deployBridge(
            l2Signer,
            l2AddressManager,
            enabledDestChainId
        ));

        await addressManager.setAddress(
            `${enabledDestChainId}.bridge`,
            l2Bridge.address
        );

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${srcChainId}.bridge`, l1Bridge.address);

        l1XchainSync = await (await ethers.getContractFactory("TestXchainSync"))
            .connect(owner)
            .deploy();

        await addressManager
            .connect(owner)
            .setAddress(`${srcChainId}.taiko`, l1XchainSync.address);

        l2XchainSync = await (await ethers.getContractFactory("TestXchainSync"))
            .connect(l2Signer)
            .deploy();

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${enabledDestChainId}.taiko`, l2XchainSync.address);

        m = {
            id: 1,
            sender: owner.address,
            srcChainId: srcChainId,
            destChainId: enabledDestChainId,
            owner: owner.address,
            to: owner.address,
            refundAddress: owner.address,
            depositValue: 1000,
            callValue: 1000,
            processingFee: 1000,
            gasLimit: 10000,
            data: ethers.constants.HashZero,
            memo: "",
        };
    });

    describe("processMessage()", function () {
        it("should throw if message.gasLimit == 0 & msg.sender is not message.owner", async function () {
            const m: Message = {
                id: 1,
                sender: await l2NonOwner.getAddress(),
                srcChainId: srcChainId,
                destChainId: enabledDestChainId,
                owner: await l2NonOwner.getAddress(),
                to: await l2Signer.getAddress(),
                refundAddress: await l2NonOwner.getAddress(),
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const { msgHash } = await sendMessage(l1Bridge, m);

            expect(msgHash).not.to.be.eq(ethers.constants.HashZero);

            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(m, ethers.constants.HashZero, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_FORBIDDEN()"
            );
        });

        it("should throw if message.destChainId is not equal to current block.chainId", async function () {
            const m: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: enabledDestChainId + 1,
                owner: owner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 10000,
                data: ethers.constants.HashZero,
                memo: "",
            };

            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(m, ethers.constants.HashZero, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_WRONG_CHAIN_ID()"
            );
        });

        it("should throw if messageStatus of message is != NEW", async function () {
            const { message, signalProof } = await sendAndProcessMessage(
                hre.ethers.provider,
                l2XchainSync,
                m,
                l1SignalService,
                l1Bridge,
                l2Bridge
            );

            // recalling this process should be prevented as it's status is no longer NEW
            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(message, signalProof, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_STATUS_MISMATCH()"
            );
        });

        it("should throw if message signalproof is not valid", async function () {
            const msgHash = await l1Bridge.hashMessage(m);
            const { block, blockHeader } = await getBlockHeader(
                hre.ethers.provider
            );

            await l2XchainSync.setSyncedHeader(ethers.constants.HashZero);

            const signalProof = await getSignalProof(
                hre.ethers.provider,
                l1SignalService.address,
                await l1SignalService.getSignalSlot(l1Bridge.address, msgHash),
                block.number,
                blockHeader
            );

            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(m, signalProof, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_SIGNAL_NOT_RECEIVED()"
            );
        });

        it("should throw if message has not been received", async function () {
            const { msgHash, message } = await sendMessage(l1Bridge, m);

            expect(msgHash).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(msgHash);

            expect(messageStatus).to.be.eq(0);

            const sender = l1Bridge.address;

            const { block, blockHeader } = await getBlockHeader(
                hre.ethers.provider
            );

            await l2XchainSync.setSyncedHeader(ethers.constants.HashZero);

            const slot = await l1SignalService.getSignalSlot(sender, msgHash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1SignalService.address,
                slot,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre.ethers.provider,
                l1SignalService.address,
                slot,
                block.number,
                blockHeader
            );

            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(message, signalProof, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_SIGNAL_NOT_RECEIVED()"
            );
        });

        it("processes a message when the signal has been verified from the sending chain", async () => {
            const { msgHash, message } = await sendMessage(l1Bridge, m);

            expect(msgHash).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(msgHash);

            expect(messageStatus).to.be.eq(0);
            let block: Block;
            expect(
                ({ block } = await processMessage(
                    l1SignalService,
                    l1Bridge,
                    l2Bridge,
                    msgHash,
                    hre.ethers.provider,
                    l2XchainSync,
                    message
                ))
            ).to.emit(l2Bridge, "MessageStatusChanged");

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1SignalService.address,
                await l1SignalService.getSignalSlot(l1Bridge.address, msgHash),
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            txShouldRevertWithCustomError(
                (
                    await l2Bridge
                        .connect(l2Signer)
                        .processMessage(m, ethers.constants.HashZero, {
                            gasLimit: 1000000,
                        })
                ).wait(1),
                l2Provider,
                "B_WRONG_CHAIN_ID()"
            );
        });
    });

    describe("isMessageSent()", function () {
        it("should return false, since no message was sent", async function () {
            const msgHash = await l1Bridge.hashMessage(m);

            expect(await l1Bridge.isMessageSent(msgHash)).to.be.false;
        });

        it("should return true if message was sent properly", async function () {
            const { msgHash } = await sendMessage(l1Bridge, m);

            expect(msgHash).not.to.be.eq(ethers.constants.HashZero);

            expect(await l1Bridge.isMessageSent(msgHash)).to.be.true;
        });
    });

    describe("isMessageReceived()", function () {
        it("should throw if signal is not a bridge message; proof is invalid since sender != bridge.", async function () {
            const msgHash = ethers.utils.hexlify(ethers.utils.randomBytes(32));

            const tx = await l1SignalService.connect(owner).sendSignal(msgHash);

            await tx.wait();

            const sender = owner.address;

            const slot = await l1SignalService.getSignalSlot(sender, msgHash);

            const { block, blockHeader } = await getBlockHeader(
                hre.ethers.provider
            );

            await l2XchainSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1SignalService.address,
                slot,
                block.number
            );
            // make sure it equals 1 so we know sendSignal worked
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre.ethers.provider,
                l1SignalService.address,
                slot,
                block.number,
                blockHeader
            );

            await expect(
                l2Bridge.isMessageReceived(msgHash, srcChainId, signalProof)
            ).to.be.reverted;
        });

        it("if message is valid and sent by the bridge it should return true", async function () {
            const { msgHash } = await sendMessage(l1Bridge, m);
            const slot = await l1SignalService.getSignalSlot(
                l1Bridge.address,
                msgHash
            );

            const { block, blockHeader } = await getBlockHeader(
                hre.ethers.provider
            );

            await l2XchainSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1SignalService.address,
                slot,
                block.number
            );
            // make sure it equals 1 so we know sendMessage worked
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre.ethers.provider,
                l1SignalService.address,
                slot,
                block.number,
                blockHeader
            );

            expect(
                await l2Bridge.isMessageReceived(
                    msgHash,
                    srcChainId,
                    signalProof
                )
            ).to.be.true;
        });
    });

    describe("isMessageFailed()", function () {
        it("should revert if destChainId == block.chainid", async function () {
            const testBadReceiver: TestBadReceiver = await (
                await ethers.getContractFactory("TestBadReceiver")
            )
                .connect(owner)
                .deploy();
            await testBadReceiver.deployed();

            const m: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: enabledDestChainId,
                destChainId: srcChainId,
                owner: owner.address,
                to: testBadReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 10,
                processingFee: 1,
                gasLimit: 300000,
                data: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
                memo: "",
            };
            const { msgHash } = await sendMessage(l2Bridge, m);

            await expect(
                l2Bridge.isMessageFailed(
                    msgHash,
                    enabledDestChainId,
                    ethers.constants.HashZero
                )
            ).to.be.revertedWith("B_WRONG_CHAIN_ID()");
        });

        it("should revert if msgHash == 0", async function () {
            await expect(
                l2Bridge.isMessageFailed(
                    ethers.constants.HashZero,
                    srcChainId,
                    ethers.constants.HashZero
                )
            ).to.be.revertedWith("B_MSG_HASH_NULL()");
        });

        it("should return false if headerHash hasn't been synced", async function () {
            const testBadReceiver: TestBadReceiver = await (
                await ethers.getContractFactory("TestBadReceiver")
            )
                .connect(owner)
                .deploy();
            await testBadReceiver.deployed();

            const m: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: enabledDestChainId,
                destChainId: srcChainId,
                owner: owner.address,
                to: testBadReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 10,
                processingFee: 1,
                gasLimit: 300000,
                data: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
                memo: "",
            };

            const { msgHash, message } = await sendMessage(l2Bridge, m);

            const messageStatus = await l1Bridge.getMessageStatus(msgHash);
            expect(messageStatus).to.be.eq(0);

            const { messageStatusChangedEvent } = await processMessage(
                l2SignalService,
                l2Bridge,
                l1Bridge,
                msgHash,
                l2Provider,
                l1XchainSync,
                message
            );
            expect(messageStatusChangedEvent.args.msgHash).to.be.eq(msgHash);
            expect(messageStatusChangedEvent.args.status).to.be.eq(1);

            const tx = await l1Bridge
                .connect(owner)
                .retryMessage(message, true);
            const receipt = await tx.wait();
            expect(receipt.status).to.be.eq(1);

            const messageStatus2 = await l1Bridge.getMessageStatus(msgHash);
            expect(messageStatus2).to.be.eq(3);
            // message status is FAILED on l1Bridge now.

            const { block, blockHeader } = await getBlockHeader(l1Provider);

            const slot = await l1Bridge.getMessageStatusSlot(msgHash);

            const signalProof = await getSignalProof(
                l1Provider,
                l1Bridge.address,
                slot,
                block.number,
                blockHeader
            );

            expect(
                await l2Bridge.isMessageFailed(msgHash, srcChainId, signalProof)
            ).to.be.false;
        });

        it("should return true if message has been sent, processed, retried and failed", async function () {
            // L2 -> L1 message
            const testBadReceiver: TestBadReceiver = await (
                await ethers.getContractFactory("TestBadReceiver")
            )
                .connect(owner)
                .deploy();
            await testBadReceiver.deployed();

            const m: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: enabledDestChainId,
                destChainId: srcChainId,
                owner: owner.address,
                to: testBadReceiver.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 10,
                processingFee: 1,
                gasLimit: 300000,
                data: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
                memo: "",
            };

            const { msgHash, message } = await sendMessage(l2Bridge, m);

            const messageStatus = await l1Bridge.getMessageStatus(msgHash);
            expect(messageStatus).to.be.eq(0);

            const { messageStatusChangedEvent } = await processMessage(
                l2SignalService,
                l2Bridge,
                l1Bridge,
                msgHash,
                l2Provider,
                l1XchainSync,
                message
            );
            expect(messageStatusChangedEvent.args.msgHash).to.be.eq(msgHash);
            expect(messageStatusChangedEvent.args.status).to.be.eq(1);

            const tx = await l1Bridge
                .connect(owner)
                .retryMessage(message, true);
            const receipt = await tx.wait();
            expect(receipt.status).to.be.eq(1);

            const messageStatus2 = await l1Bridge.getMessageStatus(msgHash);
            expect(messageStatus2).to.be.eq(3);
            // message status is FAILED on l1Bridge now.

            const { block, blockHeader } = await getBlockHeader(l1Provider);

            await l2XchainSync.setSyncedHeader(block.hash);

            const slot = await l1Bridge.getMessageStatusSlot(msgHash);

            const signalProof = await getSignalProof(
                l1Provider,
                l1Bridge.address,
                slot,
                block.number,
                blockHeader
            );

            expect(
                await l2Bridge.isMessageFailed(msgHash, srcChainId, signalProof)
            ).to.be.true;
        });
    });
});
