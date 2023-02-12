import { expect } from "chai";
import { ethers } from "hardhat";
import { TestHeaderSync } from "../../typechain";
import { deploySignalService, getSignalProof } from "../utils/signal";
import deployAddressManager from "../utils/addressManager";
import { getBlockHeader } from "../utils/rpc";
import {
    getDefaultL2Signer,
    getL1Provider,
    getL2Provider,
} from "../utils/provider";

describe("integration:SignalService", function () {
    async function deployIntegrationSignalService() {
        const [owner] = await ethers.getSigners();

        const { chainId: srcChainId } = await ethers.provider.getNetwork();

        // ethereum node
        const l1Provider = await getL1Provider();

        // hardhat node
        const l2Provider = await getL2Provider();

        const l1Signer = await ethers.provider.getSigner();

        const l2Signer = await getDefaultL2Signer();

        const l2Network = await l2Provider.getNetwork();
        const enabledDestChainId = l2Network.chainId;

        const addressManager = await deployAddressManager(l1Signer);
        const l2AddressManager = await deployAddressManager(l2Signer);

        const { signalService: l1SignalService } = await deploySignalService(
            owner,
            addressManager,
            srcChainId
        );

        const { signalService: l2SignalService } = await deploySignalService(
            l2Signer,
            l2AddressManager,
            enabledDestChainId
        );

        await addressManager.setAddress(
            `${enabledDestChainId}.signal_service`,
            l2SignalService.address
        );

        await l2AddressManager.setAddress(
            `${srcChainId}.signal_service`,
            l1SignalService.address
        );

        const headerSync: TestHeaderSync = await (
            await ethers.getContractFactory("TestHeaderSync")
        )
            .connect(l2Signer)
            .deploy();

        await l2AddressManager.setAddress(
            `${enabledDestChainId}.taiko`,
            headerSync.address
        );

        return {
            l1Provider,
            owner,
            l1SignalService,
            l2SignalService,
            srcChainId,
            enabledDestChainId,
            headerSync,
        };
    }

    it("should revert if srcChainId == block.chainId", async function () {
        const {
            l1Provider,
            owner,
            l1SignalService,
            l2SignalService,
            enabledDestChainId,
            headerSync,
        } = await deployIntegrationSignalService();

        const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

        const tx = await l1SignalService.connect(owner).sendSignal(signal);
        await tx.wait();

        const app = owner.address;
        const slot = await l1SignalService.getSignalSlot(app, signal);

        const { block, blockHeader } = await getBlockHeader(l1Provider);
        await headerSync.setSyncedHeader(block.hash);

        const signalProof = await getSignalProof(
            l1Provider,
            l1SignalService.address,
            slot,
            block.number,
            blockHeader
        );

        await expect(
            l2SignalService.isSignalReceived(
                enabledDestChainId,
                app,
                signal,
                signalProof
            )
        ).to.be.revertedWith("B:srcChainId");
    });

    it("should revert if app == AddressZero", async function () {
        const {
            l1Provider,
            owner,
            l1SignalService,
            l2SignalService,
            srcChainId,
            headerSync,
        } = await deployIntegrationSignalService();

        const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

        const tx = await l1SignalService.connect(owner).sendSignal(signal);
        await tx.wait();

        const app = ethers.constants.AddressZero;
        const slot = await l1SignalService.getSignalSlot(app, signal);

        const { block, blockHeader } = await getBlockHeader(l1Provider);
        await headerSync.setSyncedHeader(block.hash);

        const signalProof = await getSignalProof(
            l1Provider,
            l1SignalService.address,
            slot,
            block.number,
            blockHeader
        );

        await expect(
            l2SignalService.isSignalReceived(
                srcChainId,
                app,
                signal,
                signalProof
            )
        ).to.be.revertedWith("B:app");
    });

    it("should revert if signal == HashZero", async function () {
        const {
            l1Provider,
            owner,
            l1SignalService,
            l2SignalService,
            srcChainId,
            headerSync,
        } = await deployIntegrationSignalService();

        const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

        const tx = await l1SignalService.connect(owner).sendSignal(signal);
        await tx.wait();

        const app = owner.address;
        const slot = await l1SignalService.getSignalSlot(app, signal);

        const { block, blockHeader } = await getBlockHeader(l1Provider);
        await headerSync.setSyncedHeader(block.hash);

        const signalProof = await getSignalProof(
            l1Provider,
            l1SignalService.address,
            slot,
            block.number,
            blockHeader
        );

        await expect(
            l2SignalService.isSignalReceived(
                srcChainId,
                app,
                ethers.constants.HashZero,
                signalProof
            )
        ).to.be.revertedWith("B:signal");
    });

    it("should pass and return true", async function () {
        const {
            l1Provider,
            owner,
            l1SignalService,
            l2SignalService,
            srcChainId,
            headerSync,
        } = await deployIntegrationSignalService();

        const signal = ethers.utils.hexlify(ethers.utils.randomBytes(32));

        const tx = await l1SignalService.connect(owner).sendSignal(signal);
        await tx.wait();

        const app = owner.address;
        const slot = await l1SignalService.getSignalSlot(app, signal);

        const { block, blockHeader } = await getBlockHeader(l1Provider);

        const failProof = await getSignalProof(
            l1Provider,
            l1SignalService.address,
            slot,
            block.number,
            blockHeader
        );
        // should return false since header has not been synced yet.
        expect(
            await l2SignalService.isSignalReceived(
                srcChainId,
                app,
                signal,
                failProof
            )
        ).to.be.equal(false);

        await headerSync.setSyncedHeader(block.hash);

        const signalProof = await getSignalProof(
            l1Provider,
            l1SignalService.address,
            slot,
            block.number,
            blockHeader
        );

        expect(
            await l2SignalService.isSignalReceived(
                srcChainId,
                app,
                signal,
                signalProof
            )
        ).to.be.eq(true);
    });
});
