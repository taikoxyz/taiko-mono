import { expect } from "chai";
import { BigNumber, ethers as ethersLib } from "ethers";
import hre, { ethers } from "hardhat";
import {
    AddressManager,
    Bridge,
    TestHeaderSync,
    TestLibBridgeData,
} from "../../typechain";
import { deployBridge, sendMessage } from "../utils/bridge";
import { randomBytes32 } from "../utils/bytes";
import { Message } from "../utils/message";
import { getLatestBlockHeader } from "../utils/rpc";
import { getSignalProof, getSignalSlot } from "../utils/signal";

describe("integration:Bridge", function () {
    let owner: any;
    let l2Provider: ethersLib.providers.JsonRpcProvider;
    let l2Signer: ethersLib.Signer;
    let srcChainId: number;
    let enabledDestChainId: number;
    let l2NonOwner: ethersLib.Signer;
    let l1Bridge: Bridge;
    let l2Bridge: Bridge;
    let m: Message;
    let headerSync: TestHeaderSync;

    beforeEach(async () => {
        [owner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        srcChainId = chainId;

        // seondary node to deploy L2 on
        l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        l2Signer = await l2Provider.getSigner(
            (
                await l2Provider.listAccounts()
            )[0]
        );

        l2NonOwner = await l2Provider.getSigner();

        const l2Network = await l2Provider.getNetwork();

        enabledDestChainId = l2Network.chainId;

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const l2AddressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        )
            .connect(l2Signer)
            .deploy();
        await l2AddressManager.init();

        ({ bridge: l1Bridge } = await deployBridge(
            owner,
            addressManager,
            enabledDestChainId,
            srcChainId
        ));

        ({ bridge: l2Bridge } = await deployBridge(
            l2Signer,
            l2AddressManager,
            srcChainId,
            enabledDestChainId
        ));

        await addressManager.setAddress(
            `${enabledDestChainId}.bridge`,
            l2Bridge.address
        );

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${srcChainId}.bridge`, l1Bridge.address);

        headerSync = await (await ethers.getContractFactory("TestHeaderSync"))
            .connect(l2Signer)
            .deploy();

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${enabledDestChainId}.taiko`, headerSync.address);

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
                owner: owner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };

            await expect(
                l2Bridge.processMessage(m, ethers.constants.HashZero)
            ).to.be.revertedWith("B:forbidden");
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

            await expect(
                l2Bridge.processMessage(m, ethers.constants.HashZero)
            ).to.be.revertedWith("B:destChainId");
        });

        it("should throw if messageStatus of message is != NEW", async function () {
            const { signal, message } = await sendMessage(l1Bridge, m);
            const sender = l1Bridge.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            // upon successful processing, this immediately gets marked as DONE
            await l2Bridge.processMessage(message, signalProof);

            // recalling this process should be prevented as it's status is no longer NEW
            await expect(
                l2Bridge.processMessage(message, signalProof)
            ).to.be.revertedWith("B:status");
        });

        it("should throw if message signalproof is not valid", async function () {
            const libData: TestLibBridgeData = await (
                await ethers.getContractFactory("TestLibBridgeData")
            ).deploy();

            const signal = await libData.hashMessage(m);

            const sender = l1Bridge.address;

            const key = getSignalSlot(hre, sender, signal);
            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(ethers.constants.HashZero);

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            await expect(
                l2Bridge.processMessage(m, signalProof)
            ).to.be.revertedWith("LTP:invalid storage proof");
        });

        it("should throw if message has not been received", async function () {
            const { signal, message } = await sendMessage(l1Bridge, m);

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(signal);

            expect(messageStatus).to.be.eq(0);

            const sender = l1Bridge.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(ethers.constants.HashZero);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            await expect(
                l2Bridge.processMessage(message, signalProof)
            ).to.be.revertedWith("B:notReceived");
        });

        it("processes a message when the signal has been verified from the sending chain", async () => {
            const { signal, message } = await sendMessage(l1Bridge, m);

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(signal);

            expect(messageStatus).to.be.eq(0);

            const sender = l1Bridge.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            expect(
                await l2Bridge.processMessage(message, signalProof, {
                    gasLimit: BigNumber.from(2000000),
                })
            ).to.emit(l2Bridge, "MessageStatusChanged");
        });
    });

    describe("isMessageSent()", function () {
        it("should return false, since no message was sent", async function () {
            const libData = await (
                await ethers.getContractFactory("TestLibBridgeData")
            ).deploy();
            const signal = await libData.hashMessage(m);

            expect(await l1Bridge.isMessageSent(signal)).to.be.eq(false);
        });

        it("should return true if message was sent properly", async function () {
            const { signal } = await sendMessage(l1Bridge, m);

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            expect(await l1Bridge.isMessageSent(signal)).to.be.eq(true);
        });
    });

    describe("isMessageReceived()", function () {
        it("should throw if signal is not a bridge message; proof is invalid since sender != bridge.", async function () {
            const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

            const tx = await l1Bridge.connect(owner).sendSignal(signal);

            await tx.wait();

            const sender = owner.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // // make sure it equals 1 so we know sendSignal worked
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            await expect(
                l2Bridge.isMessageReceived(signal, srcChainId, signalProof)
            ).to.be.reverted;
        });

        it("should return true", async function () {
            const { signal } = await sendMessage(l1Bridge, m);

            const sender = l1Bridge.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // // make sure it equals 1 so we know sendMessage worked
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            expect(
                await l2Bridge.isMessageReceived(
                    signal,
                    srcChainId,
                    signalProof
                )
            ).to.be.eq(true);
        });
    });

    describe("isSignalReceived()", function () {
        it("should throw if sender == address(0)", async function () {
            const signal = randomBytes32();
            const sender = ethers.constants.AddressZero;
            const signalProof = ethers.constants.HashZero;

            await expect(
                l2Bridge.isSignalReceived(
                    signal,
                    srcChainId,
                    sender,
                    signalProof
                )
            ).to.be.revertedWith("B:sender");
        });

        it("should throw if signal == HashZero", async function () {
            const signal = ethers.constants.HashZero;
            const sender = owner.address;
            const signalProof = ethers.constants.HashZero;

            await expect(
                l2Bridge.isSignalReceived(
                    signal,
                    srcChainId,
                    sender,
                    signalProof
                )
            ).to.be.revertedWith("B:signal");
        });

        it("should throw if calling from same layer", async function () {
            const signal = randomBytes32();

            const tx = await l1Bridge.connect(owner).sendSignal(signal);

            await tx.wait();

            const sender = owner.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof is valid
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );

            await expect(
                l1Bridge.isSignalReceived(
                    signal,
                    srcChainId,
                    sender,
                    signalProof
                )
            ).to.be.revertedWith("B:srcBridge");
        });

        it("should return true and pass", async function () {
            const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

            const tx = await l1Bridge.connect(owner).sendSignal(signal);

            await tx.wait();

            const sender = owner.address;

            const key = getSignalSlot(hre, sender, signal);

            const { block, blockHeader } = await getLatestBlockHeader(hre);

            await headerSync.setSyncedHeader(block.hash);

            // get storageValue for the key
            const storageValue = await ethers.provider.getStorageAt(
                l1Bridge.address,
                key,
                block.number
            );
            // make sure it equals 1 so our proof will pass
            expect(storageValue).to.be.eq(
                "0x0000000000000000000000000000000000000000000000000000000000000001"
            );

            const signalProof = await getSignalProof(
                hre,
                l1Bridge.address,
                key,
                block.number,
                blockHeader
            );
            // proving functionality; l2Bridge can check if l1Bridge receives a signal
            // allowing for dapp cross layer communication
            expect(
                await l2Bridge.isSignalReceived(
                    signal,
                    srcChainId,
                    sender,
                    signalProof
                )
            ).to.be.eq(true);
        });
    });
});
