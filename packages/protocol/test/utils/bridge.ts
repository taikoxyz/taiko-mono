import { BigNumber, ethers, Signer } from "ethers";
import { ethers as hardhatEthers } from "hardhat";
import {
    AddressManager,
    Bridge,
    SignalService,
    EtherVault,
    TestXchainSync,
    LibTrieProof,
} from "../../typechain";
import { MessageStatusChangedEvent } from "../../typechain/LibBridgeStatus";
import { Message } from "./message";
import { Block, BlockHeader, getBlockHeader } from "./rpc";
import { getSignalProof } from "./signal";

async function deployBridge(
    signer: Signer,
    addressManager: AddressManager,
    chainId: number
): Promise<{ bridge: Bridge; etherVault: EtherVault }> {
    const libTrieProof: LibTrieProof = await (
        await hardhatEthers.getContractFactory("LibTrieProof")
    )
        .connect(signer)
        .deploy();

    const BridgeFactory = await hardhatEthers.getContractFactory("TestBridge", {
        libraries: {
            LibTrieProof: libTrieProof.address,
        },
    });

    const bridge: Bridge = await BridgeFactory.connect(signer).deploy();

    await bridge.connect(signer).init(addressManager.address);

    const etherVault: EtherVault = await (
        await hardhatEthers.getContractFactory("TestEtherVault")
    )
        .connect(signer)
        .deploy();

    await etherVault.connect(signer).init(addressManager.address);

    await etherVault.connect(signer).authorize(bridge.address, true);

    await etherVault.connect(signer).authorize(await signer.getAddress(), true);

    await addressManager.setAddress(
        `${chainId}.ether_vault`,
        etherVault.address
    );

    await signer.sendTransaction({
        to: etherVault.address,
        value: BigNumber.from(100000000),
        gasLimit: 1000000,
    });

    await addressManager.setAddress(`${chainId}.bridge`, bridge.address);

    return { bridge, etherVault };
}

async function sendMessage(
    bridge: Bridge,
    m: Message
): Promise<{
    bridge: Bridge;
    msgHash: string;
    messageSentEvent: any;
    message: Message;
    tx: ethers.ContractTransaction;
}> {
    const expectedAmount = m.depositValue + m.callValue + m.processingFee;

    const tx = await bridge.sendMessage(m, {
        value: expectedAmount,
    });

    const receipt = await tx.wait();

    const [messageSentEvent] = receipt.events as any as Event[];

    const { msgHash, message } = (messageSentEvent as any).args;

    return { bridge, messageSentEvent, msgHash, message, tx };
}

// Process a L1-to-L1 message
async function processMessage(
    l1SignalService: SignalService,
    l1Bridge: Bridge,
    l2Bridge: Bridge,
    signal: string,
    provider: ethers.providers.JsonRpcProvider,
    xchainSync: TestXchainSync,
    message: Message
): Promise<{
    tx: ethers.ContractTransaction;
    signalProof: string;
    block: Block;
    blockHeader: BlockHeader;
    messageStatusChangedEvent: MessageStatusChangedEvent;
}> {
    const sender = l1Bridge.address;

    const slot = await l1SignalService.getSignalSlot(sender, signal);

    const { block, blockHeader } = await getBlockHeader(provider);

    await xchainSync.setXchainBlockHeader(block.hash);

    const { signalProof, signalRoot } = await getSignalProof(
        provider,
        l1SignalService.address,
        slot,
        block.number,
        blockHeader
    );

    await xchainSync.setXchainSignalRoot(signalRoot);

    const tx = await l2Bridge.processMessage(message, signalProof);
    const receipt = await tx.wait(1);
    const messageStatusChangedEvent = (receipt.events || []).find(
        (e) => e.event === "MessageStatusChanged"
    ) as any as MessageStatusChangedEvent;
    return { tx, signalProof, block, blockHeader, messageStatusChangedEvent };
}

async function sendAndProcessMessage(
    provider: ethers.providers.JsonRpcProvider,
    xchainSync: TestXchainSync,
    m: Message,
    l1SignalService: SignalService,
    l1Bridge: Bridge,
    l2Bridge: Bridge
): Promise<{
    tx: ethers.ContractTransaction;
    message: Message;
    msgHash: string;
    signalProof: string;
}> {
    const { msgHash, message } = await sendMessage(l1Bridge, m);
    const { tx, signalProof } = await processMessage(
        l1SignalService,
        l1Bridge,
        l2Bridge,
        msgHash,
        provider,
        xchainSync,
        message
    );
    return { tx, msgHash, message, signalProof };
}

export { deployBridge, sendMessage, processMessage, sendAndProcessMessage };
