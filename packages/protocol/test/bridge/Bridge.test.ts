import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import {
    getLatestBlockHeader,
    getSignalProof,
    getSignalSlot,
} from "../../tasks/utils";
import {
    AddressManager,
    Bridge,
    EtherVault,
    SignalService,
    TestBadReceiver,
    TestHeaderSync,
    TestLibBridgeData,
} from "../../typechain";
import { Message } from "../utils/message";

async function deploySignalService(
    signer: Signer,
    addressManager: AddressManager,
    srcChain: number
): Promise<{ signalService: SignalService }> {
    const libTrieProof = await (await ethers.getContractFactory("LibTrieProof"))
        .connect(signer)
        .deploy();

    const SignalServiceFactory = await ethers.getContractFactory(
        "SignalService",
        {
            libraries: {
                LibTrieProof: libTrieProof.address,
            },
        }
    );

    const signalService: SignalService = await SignalServiceFactory.connect(
        signer
    ).deploy();

    await signalService.connect(signer).init(addressManager.address);

    await addressManager.setAddress(
        `${srcChain}.signal_service`,
        signalService.address
    );

    return { signalService };
}

async function deployBridge(
    signer: Signer,
    addressManager: AddressManager,
    destChain: number,
    srcChain: number
): Promise<{ bridge: Bridge; etherVault: EtherVault }> {
    const libBridgeProcess = await (
        await ethers.getContractFactory("LibBridgeProcess")
    )
        .connect(signer)
        .deploy();

    const libBridgeRetry = await (
        await ethers.getContractFactory("LibBridgeRetry")
    )
        .connect(signer)
        .deploy();

    const BridgeFactory = await ethers.getContractFactory("Bridge", {
        libraries: {
            LibBridgeProcess: libBridgeProcess.address,
            LibBridgeRetry: libBridgeRetry.address,
        },
    });

    const bridge: Bridge = await BridgeFactory.connect(signer).deploy();

    await bridge.connect(signer).init(addressManager.address);

    await bridge.connect(signer).enableDestChain(destChain, true);

    const etherVault: EtherVault = await (
        await ethers.getContractFactory("EtherVault")
    )
        .connect(signer)
        .deploy();

    await etherVault.connect(signer).init(addressManager.address);

    await etherVault.connect(signer).authorize(bridge.address, true);

    await etherVault.connect(signer).authorize(await signer.getAddress(), true);

    await addressManager.setAddress(
        `${srcChain}.ether_vault`,
        etherVault.address
    );

    await signer.sendTransaction({
        to: etherVault.address,
        value: BigNumber.from(100000000),
        gasLimit: 1000000,
    });

    return { bridge, etherVault };
}
describe("Bridge", function () {
    async function deployBridgeFixture() {
        const [owner, nonOwner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        const srcChainId = chainId;

        const enabledDestChainId = srcChainId + 1;

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        const { signalService } = await deploySignalService(
            owner,
            addressManager,
            srcChainId
        );

        const { bridge: l1Bridge, etherVault: l1EtherVault } =
            await deployBridge(
                owner,
                addressManager,
                enabledDestChainId,
                srcChainId
            );

        // deploy protocol contract
        return {
            owner,
            nonOwner,
            signalService,
            l1Bridge,
            addressManager,
            enabledDestChainId,
            l1EtherVault,
            srcChainId,
        };
    }

    describe("sendMessage()", function () {
        it("throws when owner is the zero address", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: ethers.constants.AddressZero,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:owner"
            );
        });

        it("throws when dest chain id is same as block.chainid", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture();

            const network = await ethers.provider.getNetwork();
            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: network.chainId,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            );
        });

        it("throws when dest chain id is not enabled", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:destChainId"
            );
        });

        it("throws when msg.value is not the same as expected amount", async () => {
            const { owner, nonOwner, l1Bridge, enabledDestChainId } =
                await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: enabledDestChainId,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            await expect(l1Bridge.sendMessage(message)).to.be.revertedWith(
                "B:value"
            );
        });

        it("emits event and is successful when message is valid, ether_vault receives the expectedAmount", async () => {
            const {
                owner,
                nonOwner,
                l1EtherVault,
                l1Bridge,
                enabledDestChainId,
            } = await deployBridgeFixture();

            const etherVaultOriginalBalance = await ethers.provider.getBalance(
                l1EtherVault.address
            );

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: enabledDestChainId,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const expectedAmount =
                message.depositValue +
                message.callValue +
                message.processingFee;
            await expect(
                l1Bridge.sendMessage(message, {
                    value: expectedAmount,
                })
            ).to.emit(l1Bridge, "MessageSent");

            const etherVaultUpdatedBalance = await ethers.provider.getBalance(
                l1EtherVault.address
            );

            expect(etherVaultUpdatedBalance).to.be.eq(
                etherVaultOriginalBalance.add(expectedAmount)
            );
        });
    });

    describe("isDestChainEnabled()", function () {
        it("is disabled for unabled chainIds", async () => {
            const { l1Bridge } = await deployBridgeFixture();

            const enabled = await l1Bridge.isDestChainEnabled(68);
            expect(enabled).to.be.eq(false);
        });

        it("is enabled for enabled chainId", async () => {
            const { l1Bridge, enabledDestChainId } =
                await deployBridgeFixture();

            const enabled = await l1Bridge.isDestChainEnabled(
                enabledDestChainId
            );
            expect(enabled).to.be.eq(true);
        });
    });

    describe("context()", function () {
        it("returns unitialized context", async () => {
            const { l1Bridge } = await deployBridgeFixture();

            const ctx = await l1Bridge.context();
            expect(ctx[0]).to.be.eq(ethers.constants.HashZero);
            expect(ctx[1]).to.be.eq(ethers.constants.AddressZero);
            expect(ctx[2]).to.be.eq(BigNumber.from(0));
        });
    });

    describe("getMessageStatus()", function () {
        it("returns new for uninitialized signal", async () => {
            const { l1Bridge } = await deployBridgeFixture();

            const messageStatus = await l1Bridge.getMessageStatus(
                ethers.constants.HashZero
            );

            expect(messageStatus).to.be.eq(0);
        });

        it("returns for initiaized signal", async () => {
            const { owner, nonOwner, enabledDestChainId, l1Bridge } =
                await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: enabledDestChainId,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 100,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const expectedAmount =
                message.depositValue +
                message.callValue +
                message.processingFee;

            const tx = await l1Bridge.sendMessage(message, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal } = (messageSentEvent as any).args;

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(signal);

            expect(messageStatus).to.be.eq(0);
        });
    });

    describe("processMessage()", async function () {
        it("throws when message.gasLimit is 0 and msg.sender is not the message.owner", async () => {
            const { owner, nonOwner, l1Bridge, enabledDestChainId } =
                await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: 1,
                destChainId: enabledDestChainId,
                owner: nonOwner.address,
                to: owner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const proof = ethers.constants.HashZero;

            await expect(
                l1Bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:forbidden");
        });

        it("throws message.destChainId is not block.chainId", async () => {
            const { owner, nonOwner, l1Bridge } = await deployBridgeFixture();

            const message: Message = {
                id: 1,
                sender: nonOwner.address,
                srcChainId: 1,
                destChainId: 5,
                owner: owner.address,
                to: nonOwner.address,
                refundAddress: owner.address,
                depositValue: 1,
                callValue: 1,
                processingFee: 1,
                gasLimit: 0,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const proof = ethers.constants.HashZero;

            await expect(
                l1Bridge.processMessage(message, proof)
            ).to.be.revertedWith("B:destChainId");
        });
    });
});

describe("integration:Bridge", function () {
    async function deployBridgeFixture() {
        const [owner, nonOwner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        const srcChainId = chainId;

        // seondary node to deploy L2 on
        const l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        const l2Signer = await l2Provider.getSigner(
            (
                await l2Provider.listAccounts()
            )[0]
        );

        const l2NonOwner = await l2Provider.getSigner();

        const l2Network = await l2Provider.getNetwork();
        const enabledDestChainId = l2Network.chainId;

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

        const { bridge: l1Bridge, etherVault: l1EtherVault } =
            await deployBridge(
                owner,
                addressManager,
                enabledDestChainId,
                srcChainId
            );

        const { bridge: l2Bridge, etherVault: l2EtherVault } =
            await deployBridge(
                l2Signer,
                l2AddressManager,
                srcChainId,
                enabledDestChainId
            );

        await addressManager.setAddress(
            `${enabledDestChainId}.bridge`,
            l2Bridge.address
        );

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${srcChainId}.bridge`, l1Bridge.address);

        const headerSync: TestHeaderSync = await (
            await ethers.getContractFactory("TestHeaderSync")
        )
            .connect(l2Signer)
            .deploy();

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${enabledDestChainId}.taiko`, headerSync.address);

        const m: Message = {
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

        return {
            owner,
            l2Signer,
            nonOwner,
            l2NonOwner,
            l1Bridge,
            l2Bridge,
            addressManager,
            enabledDestChainId,
            l1EtherVault,
            l2EtherVault,
            srcChainId,
            headerSync,
            m,
        };
    }

    describe("processMessage()", function () {
        it("should throw if message.gasLimit == 0 & msg.sender is not message.owner", async function () {
            const {
                owner,
                l2NonOwner,
                srcChainId,
                enabledDestChainId,
                l2Bridge,
            } = await deployBridgeFixture();

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
            const { owner, srcChainId, enabledDestChainId, l2Bridge } =
                await deployBridgeFixture();

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
            const { l1Bridge, l2Bridge, headerSync, m } =
                await deployBridgeFixture();

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal, message } = (messageSentEvent as any).args;

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
            const { l1Bridge, l2Bridge, headerSync, m } =
                await deployBridgeFixture();

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
            const { l1Bridge, l2Bridge, headerSync, m } =
                await deployBridgeFixture();

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal, message } = (messageSentEvent as any).args;

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
            const { l1Bridge, l2Bridge, headerSync, m } =
                await deployBridgeFixture();

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal, message } = (messageSentEvent as any).args;

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
            const { l1Bridge, m } = await deployBridgeFixture();

            const libData = await (
                await ethers.getContractFactory("TestLibBridgeData")
            ).deploy();
            const signal = await libData.hashMessage(m);

            expect(await l1Bridge.isMessageSent(signal)).to.be.eq(false);
        });

        it("should return true if message was sent properly", async function () {
            const { l1Bridge, m } = await deployBridgeFixture();

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal } = (messageSentEvent as any).args;

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            expect(await l1Bridge.isMessageSent(signal)).to.be.eq(true);
        });
    });

    describe("retryMessage()", function () {
        async function retriableMessageSetup() {
            const {
                owner,
                l2Signer,
                nonOwner,
                l2NonOwner,
                l1Bridge,
                l2Bridge,
                addressManager,
                enabledDestChainId,
                l1EtherVault,
                l2EtherVault,
                srcChainId,
                headerSync,
            } = await deployBridgeFixture();

            const testBadReceiver: TestBadReceiver = await (
                await ethers.getContractFactory("TestBadReceiver")
            )
                .connect(l2Signer)
                .deploy();

            await testBadReceiver.deployed();

            const m: Message = {
                id: 1,
                sender: owner.address,
                srcChainId: srcChainId,
                destChainId: enabledDestChainId,
                owner: owner.address,
                to: testBadReceiver.address,
                refundAddress: owner.address,
                depositValue: 1000,
                callValue: 1000,
                processingFee: 1000,
                gasLimit: 1,
                data: ethers.constants.HashZero,
                memo: "",
            };

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.connect(owner).sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal, message } = (messageSentEvent as any).args;

            expect(signal).not.to.be.eq(ethers.constants.HashZero);

            const messageStatus = await l1Bridge.getMessageStatus(signal);

            expect(messageStatus).to.be.eq(0);

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

            await l2Bridge
                .connect(l2NonOwner)
                .processMessage(message, signalProof, {
                    gasLimit: BigNumber.from(2000000),
                });

            const status = await l2Bridge.getMessageStatus(signal);
            expect(status).to.be.eq(1); // message is retriable now
            // because the LibBridgeInvoke call failed, because
            // message.to is a bad receiver and throws upon receipt

            return {
                message,
                l2Signer,
                l2NonOwner,
                l1Bridge,
                l2Bridge,
                addressManager,
                headerSync,
                owner,
                nonOwner,
                srcChainId,
                enabledDestChainId,
                l1EtherVault,
                l2EtherVault,
                signal,
            };
        }
        it("setup message to fail first processMessage", async function () {
            const { l2Bridge, signal } = await retriableMessageSetup();
            l2Bridge;
            signal;
        });
    });

    describe("isMessageReceived()", function () {
        it("should throw if signal is not a bridge message; proof is invalid since sender != bridge.", async function () {
            const { owner, l1Bridge, l2Bridge, headerSync, srcChainId } =
                await deployBridgeFixture();

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
            const { l1Bridge, srcChainId, l2Bridge, headerSync, m } =
                await deployBridgeFixture();

            const expectedAmount =
                m.depositValue + m.callValue + m.processingFee;
            const tx = await l1Bridge.sendMessage(m, {
                value: expectedAmount,
            });

            const receipt = await tx.wait();

            const [messageSentEvent] = receipt.events as any as Event[];

            const { signal } = (messageSentEvent as any).args;

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
            const { l2Bridge, srcChainId } = await deployBridgeFixture();

            const signal = ethers.utils.randomBytes(32);
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
            const { owner, l2Bridge, srcChainId } = await deployBridgeFixture();

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
            const { owner, l1Bridge, headerSync, srcChainId } =
                await deployBridgeFixture();
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
            const { owner, l1Bridge, l2Bridge, headerSync, srcChainId } =
                await deployBridgeFixture();

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
