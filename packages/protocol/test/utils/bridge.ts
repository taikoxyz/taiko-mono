import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import {
    AddressManager,
    Bridge,
    EtherVault,
    LibTrieProof,
} from "../../typechain";
import { Message } from "./message";

async function deployBridge(
    signer: Signer,
    addressManager: AddressManager,
    destChain: number,
    srcChain: number
): Promise<{ bridge: Bridge; etherVault: EtherVault }> {
    const libTrieProof: LibTrieProof = await (
        await ethers.getContractFactory("LibTrieProof")
    )
        .connect(signer)
        .deploy();

    const libBridgeProcess = await (
        await ethers.getContractFactory("LibBridgeProcess", {
            libraries: {
                LibTrieProof: libTrieProof.address,
            },
        })
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
            LibTrieProof: libTrieProof.address,
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

async function sendMessage(bridge: Bridge, m: Message) {
    const expectedAmount = m.depositValue + m.callValue + m.processingFee;

    const tx = await bridge.sendMessage(m, {
        value: expectedAmount,
    });

    const receipt = await tx.wait();

    const [messageSentEvent] = receipt.events as any as Event[];

    const { signal, message } = (messageSentEvent as any).args;

    return { bridge, messageSentEvent, signal, message };
}
export { deployBridge, sendMessage };
