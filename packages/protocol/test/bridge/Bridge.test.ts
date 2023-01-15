import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { AddressManager, Bridge, EtherVault } from "../../typechain";
import { deployBridge, sendMessage } from "../utils/bridge";
import { deploySignalService } from "../utils/signal";
import { Message } from "../utils/message";

describe("Bridge", function () {
    let owner: any;
    let nonOwner: any;
    let srcChainId: number;
    let enabledDestChainId: number;
    let l1Bridge: Bridge;
    let l1EtherVault: EtherVault;

    beforeEach(async () => {
        [owner, nonOwner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        srcChainId = chainId;

        enabledDestChainId = srcChainId + 1;

        const addressManager: AddressManager = await (
            await ethers.getContractFactory("AddressManager")
        ).deploy();
        await addressManager.init();

        await deploySignalService(owner, addressManager, srcChainId);

        ({ bridge: l1Bridge, etherVault: l1EtherVault } = await deployBridge(
            owner,
            addressManager,
            srcChainId
        ));

        await addressManager.setAddress(
            `${enabledDestChainId}.bridge`,
            "0x0000000000000000000000000000000000000001" // dummy address so chain is "enabled"
        );
    });

    describe("sendMessage()", function () {
        it("throws when owner is the zero address", async () => {
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

            await sendMessage(l1Bridge, message);

            const etherVaultUpdatedBalance = await ethers.provider.getBalance(
                l1EtherVault.address
            );

            expect(etherVaultUpdatedBalance).to.be.eq(
                etherVaultOriginalBalance.add(expectedAmount)
            );
        });
    });

    // TODO(roger): move tests to SignalService's test file.
    // describe("sendSignal()", async function () {
    //     it("throws when signal is empty", async function () {
    //         await expect(
    //             l1Bridge.connect(owner).sendSignal(ethers.constants.HashZero)
    //         ).to.be.revertedWith("B:signal");
    //     });

    //     it("sends signal, confirms it was sent", async function () {
    //         const hash =
    //             "0xf2e08f6b93d8cf4f37a3b38f91a8c37198095dde8697463ca3789e25218a8e9d";
    //         await expect(l1Bridge.connect(owner).sendSignal(hash))
    //             .to.emit(l1Bridge, "SignalSent")
    //             .withArgs(owner.address, hash);

    //         const isSignalSent = await l1Bridge.isSignalSent(
    //             owner.address,
    //             hash
    //         );
    //         expect(isSignalSent).to.be.eq(true);
    //     });
    // });

    describe("isDestChainEnabled()", function () {
        it("is disabled for unabled chainIds", async () => {
            const enabled = await l1Bridge.isDestChainEnabled(68);
            expect(enabled).to.be.eq(false);
        });

        it("is enabled for enabled chainId", async () => {
            const enabled = await l1Bridge.isDestChainEnabled(
                enabledDestChainId
            );
            expect(enabled).to.be.eq(true);
        });
    });

    describe("context()", function () {
        it("returns unitialized context", async () => {
            const ctx = await l1Bridge.context();
            expect(ctx[0]).to.be.eq(ethers.constants.HashZero);
            expect(ctx[1]).to.be.eq(ethers.constants.AddressZero);
            expect(ctx[2]).to.be.eq(BigNumber.from(0));
        });
    });

    describe("getMessageStatus()", function () {
        it("returns new for uninitialized signal", async () => {
            const messageStatus = await l1Bridge.getMessageStatus(
                ethers.constants.HashZero
            );

            expect(messageStatus).to.be.eq(0);
        });

        // TODO(jeff/roger): the following test is incorrect - getMessageStatus()
        // shall be tested on the destination chain, not the source chain.
        //
        // it("returns for initiaized signal", async () => {
        //     const message: Message = {
        //         id: 1,
        //         sender: owner.address,
        //         srcChainId: 1,
        //         destChainId: enabledDestChainId,
        //         owner: owner.address,
        //         to: nonOwner.address,
        //         refundAddress: owner.address,
        //         depositValue: 1,
        //         callValue: 1,
        //         processingFee: 1,
        //         gasLimit: 100,
        //         data: ethers.constants.HashZero,
        //         memo: "",
        //     };

        //     const { signal } = await sendMessage(l1Bridge, message);

        //     expect(signal).not.to.be.eq(ethers.constants.HashZero);

        //     const messageStatus = await l1Bridge.getMessageStatus(signal);

        //     expect(messageStatus).to.be.eq(0);
        // });
    });

    describe("processMessage()", async function () {
        it("throws when message.gasLimit is 0 and msg.sender is not the message.owner", async () => {
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

            await expect(
                l1Bridge.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:forbidden");
        });

        it("throws message.destChainId is not block.chainId", async () => {
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

            await expect(
                l1Bridge.processMessage(message, ethers.constants.HashZero)
            ).to.be.revertedWith("B:destChainId");
        });
    });
});
