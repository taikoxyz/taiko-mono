import { expect } from "chai";
import { ethers } from "hardhat";
import { TestHeaderSync } from "../../typechain";
import { deploySignalService, getSignalProof } from "../utils/signal";
import deployAddressManager from "../utils/addressManager";
import { getBlockHeader } from "../utils/rpc";

describe("integration:SignalService", function () {
    async function deployIntegrationSignalServiceFixture() {
        const [owner, nonOwner] = await ethers.getSigners();

        const { chainId } = await ethers.provider.getNetwork();

        const srcChainId = chainId;

        // seondary node to deploy L2 on
        const l2Provider = new ethers.providers.JsonRpcProvider(
            "http://localhost:28545"
        );

        const l1Signer = await ethers.provider.getSigner();

        const l2Signer = await l2Provider.getSigner(
            (
                await l2Provider.listAccounts()
            )[0]
        );

        const l2NonOwner = await l2Provider.getSigner();

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

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(
                `${srcChainId}.signal_service`,
                l1SignalService.address
            );

        await addressManager
            .connect(l2Signer)
            .setAddress(
                `${enabledDestChainId}.signal_service`,
                l2SignalService.address
            );

        const headerSync: TestHeaderSync = await (
            await ethers.getContractFactory("TestHeaderSync")
        )
            .connect(l2Signer)
            .deploy();

        await l2AddressManager
            .connect(l2Signer)
            .setAddress(`${enabledDestChainId}.taiko`, headerSync.address);

        return {
            l2Provider,
            owner,
            l1Signer,
            l2Signer,
            nonOwner,
            l2NonOwner,
            l1SignalService,
            l2SignalService,
            addressManager,
            l2AddressManager,
            enabledDestChainId,
            srcChainId,
            headerSync,
        };
    }

    it("test", async function () {
        const { l2Provider } = await deployIntegrationSignalServiceFixture();
        const blockHeader = await getBlockHeader(l2Provider);
        console.log(blockHeader);
        expect(true);
    });
});
