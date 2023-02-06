import { ethers } from "ethers";
import deployAddressManager from "./addressManager";
import { getDefaultL2Signer, getL1Provider, getL2Provider } from "./provider";
import { defaultFeeBase, deployTaikoL1 } from "./taikoL1";
import { deployTaikoL2 } from "./taikoL2";
import deployTkoToken from "./tkoToken";
import { ethers as hardhatEthers } from "hardhat";
import { createAndSeedWallets, sendTinyEtherToZeroAddress } from "./seed";
import { SimpleChannel } from "channel-ts";
import Proposer from "./proposer";
import Prover from "./prover";
import { AddressManager } from "../../typechain";
import { deploySignalService } from "./signal";
import { deployBridge } from "./bridge";

async function initBridgeFixture() {
    const [owner] = await hardhatEthers.getSigners();

    const { chainId } = await hardhatEthers.provider.getNetwork();

    const srcChainId = chainId;

    const l2Provider = getL2Provider();

    const l2Signer = await getDefaultL2Signer();

    const l2NonOwner = await l2Provider.getSigner();

    const l2Network = await l2Provider.getNetwork();

    const enabledDestChainId = l2Network.chainId;

    const addressManager: AddressManager = await deployAddressManager(owner);

    const l2AddressManager: AddressManager = await deployAddressManager(
        l2Signer
    );

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

    const { bridge: l1Bridge, libBridgeProcess } = await deployBridge(
        owner,
        addressManager,
        srcChainId
    );

    const { bridge: l2Bridge } = await deployBridge(
        l2Signer,
        l2AddressManager,
        enabledDestChainId
    );

    await addressManager.setAddress(
        `${enabledDestChainId}.bridge`,
        l2Bridge.address
    );

    await l2AddressManager
        .connect(l2Signer)
        .setAddress(`${srcChainId}.bridge`, l1Bridge.address);

    const l2HeaderSync = await (
        await hardhatEthers.getContractFactory("TestHeaderSync")
    )
        .connect(l2Signer)
        .deploy();

    await l2AddressManager
        .connect(l2Signer)
        .setAddress(`${enabledDestChainId}.taiko`, l2HeaderSync.address);

    const m = {
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
        l2Provider,
        l2NonOwner,
        owner,
        srcChainId,
        enabledDestChainId,
        m,
        l2AddressManager,
        l1Bridge,
        l2SignalService,
        l1SignalService,
        l2Bridge,
        l2HeaderSync,
        libBridgeProcess,
    };
}
async function initIntegrationFixture(
    mintTkoToProposer: boolean,
    enableTokenomics: boolean = true
) {
    const l1Provider = getL1Provider();

    l1Provider.pollingInterval = 100;

    const signers = await hardhatEthers.getSigners();
    const l1Signer = signers[0];

    const l2Provider = getL2Provider();

    const l2Signer = await getDefaultL2Signer();

    const l2AddressManager = await deployAddressManager(l2Signer);
    const taikoL2 = await deployTaikoL2(l2Signer, l2AddressManager, false);

    const genesisHash = taikoL2.deployTransaction.blockHash as string;
    const genesisHeight = taikoL2.deployTransaction.blockNumber as number;

    const l1AddressManager = await deployAddressManager(l1Signer);
    const taikoL1 = await deployTaikoL1(
        l1AddressManager,
        genesisHash,
        enableTokenomics,
        defaultFeeBase
    );
    const { chainId } = await l1Provider.getNetwork();

    const [proposerSigner, proverSigner] = await createAndSeedWallets(
        2,
        l1Signer
    );

    const tkoTokenL1 = await deployTkoToken(
        l1Signer,
        l1AddressManager,
        taikoL1.address
    );

    await (
        await l1AddressManager.setAddress(
            `${chainId}.tko_token`,
            tkoTokenL1.address
        )
    ).wait(1);

    const { chainId: l2ChainId } = await l2Provider.getNetwork();

    await (
        await l1AddressManager.setAddress(`${l2ChainId}.taiko`, taikoL2.address)
    ).wait(1);

    await (
        await l1AddressManager.setAddress(
            `${chainId}.proof_verifier`,
            taikoL1.address
        )
    ).wait(1);

    if (mintTkoToProposer) {
        const mintTx = await tkoTokenL1
            .connect(l1Signer)
            .mintAnyone(
                await proposerSigner.getAddress(),
                ethers.utils.parseEther("100")
            );

        await mintTx.wait(1);
    }

    // set up interval mining so we always get new blocks
    await l2Provider.send("evm_setAutomine", [true]);

    // send transactions to L1 so we always get new blocks
    const interval = setInterval(
        async () => await sendTinyEtherToZeroAddress(l1Signer),
        1 * 1000
    );

    const tx = await l2Signer.sendTransaction({
        to: proverSigner.address,
        value: ethers.utils.parseUnits("1", "ether"),
    });
    await tx.wait(1);

    const chan = new SimpleChannel<number>();
    const config = await taikoL1.getConfig();

    const proposer = new Proposer(
        taikoL1.connect(proposerSigner),
        l2Provider,
        config.commitConfirmations.toNumber(),
        config.maxNumBlocks.toNumber(),
        0,
        proposerSigner
    );

    const prover = new Prover(taikoL1, l2Provider, proverSigner);
    return {
        taikoL1,
        taikoL2,
        l1Provider,
        l2Provider,
        l1Signer,
        l2Signer,
        proposerSigner,
        proverSigner,
        genesisHeight,
        genesisHash,
        tkoTokenL1,
        l1AddressManager,
        interval,
        chan,
        config,
        proposer,
        prover,
    };
}

export { initBridgeFixture, initIntegrationFixture };
